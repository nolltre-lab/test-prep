#!/bin/bash
# docker-build-testprep.sh — build and deploy to Raspberry Pi or Lightsail
#
# Usage examples:
#   ./docker-build-testprep.sh                                    # Build & deploy to Pi (default)
#   TARGET=lightsail ./docker-build-testprep.sh                   # Build & deploy to Lightsail
#   LIGHTSAIL_IP=1.2.3.4 TARGET=lightsail ./docker-build-testprep.sh  # Lightsail with explicit IP
#   PUSH_TO_HUB=1 ./docker-build-testprep.sh                      # Direct copy + also push to Docker Hub
#   DIRECT_COPY=0 ./docker-build-testprep.sh                      # Use Docker Hub method (slower)
#   DOCKER_VERBOSE=1 ./docker-build-testprep.sh                   # Verbose Docker output
#   SKIP_DEPLOY=1 ./docker-build-testprep.sh                      # Build only (no deploy)
#   PLATFORMS=linux/amd64,linux/arm64 ./docker-build-testprep.sh  # Override platform
#   TRACE=1 ./docker-build-testprep.sh                            # Full bash debug trace
#
# Deployment targets:
#   pi (default)  — password SSH, linux/arm64, ~/apps/test-prep on Pi
#   lightsail     — key SSH, linux/amd64, /data/test-prep on Lightsail (behind apps-home Caddy)
#                   Requires: LIGHTSAIL_IP env var  OR  Keychain entry "lightsail_ip"
#                   Key path: LIGHTSAIL_KEY env var (default: ~/.ssh/lightsail.pem)
#
# Deployment methods:
#   DIRECT_COPY=1 (default): Build locally → save as tar → copy to host → load (FAST!)
#   DIRECT_COPY=0: Build, push to Docker Hub, host pulls from Hub (slower)
#
# Claude API key (optional — enables the "Write & Review" AI feedback mode):
#   Pulled from Keychain entry "testprep_anthropic_api_key" by default, or set ANTHROPIC_API_KEY
#   env var to override. Add it once with:
#     security add-generic-password -s testprep_anthropic_api_key -a "$USER" -w sk-ant-...

set -euo pipefail

########## CONFIG ##########
TARGET="${TARGET:-pi}"                                 # pi | lightsail

DOCKER_REPO="${DOCKER_REPO:-iqesolutions/test-prep}"
TAG="${TAG:-latest}"

# Pi config (password-based SSH)
REMOTE_USER="${REMOTE_USER:-magnusjohansson}"
REMOTE_HOST="${REMOTE_HOST:-raspberrypi.local}"
PI_KEYCHAIN_SERVICE="${PI_KEYCHAIN_SERVICE:-raspberrypi_scp}"

# Lightsail config (key-based SSH)
LIGHTSAIL_REMOTE_USER="${LIGHTSAIL_REMOTE_USER:-ubuntu}"
LIGHTSAIL_KEY="${LIGHTSAIL_KEY:-$HOME/.ssh/lightsail.pem}"
# LIGHTSAIL_IP: set via env var or store in Keychain as service "lightsail_ip"

# Build options
PLATFORMS="${PLATFORMS:-}"                             # Default set per-target below
DIRECT_COPY="${DIRECT_COPY:-1}"                        # 1=direct tar copy (fast), 0=Docker Hub pull
PUSH_TO_HUB="${PUSH_TO_HUB:-0}"                        # 1=also push to Docker Hub
SKIP_DEPLOY="${SKIP_DEPLOY:-0}"                        # 1=build only, no deploy
BUILDER_NAME="${BUILDER_NAME:-testprep-builder}"

# Verbosity
TRACE="${TRACE:-0}"
SSH_VERBOSE="${SSH_VERBOSE:-0}"
DOCKER_VERBOSE="${DOCKER_VERBOSE:-0}"
RETRIES="${RETRIES:-3}"
SLEEP_BETWEEN="${SLEEP_BETWEEN:-2}"

# Files to upload
CONFIG_JSON_LOCAL="${CONFIG_JSON_LOCAL:-config.json}"

# Claude API key (Anthropic) — pulled from macOS Keychain by default, same pattern as the Pi
# password / lightsail_ip lookups above. Add it once with:
#   security add-generic-password -s "testprep_anthropic_api_key" -a "$USER" -w "sk-ant-..."
# Override with ANTHROPIC_API_KEY=sk-ant-... to bypass the Keychain lookup entirely.
ANTHROPIC_KEYCHAIN_SERVICE="${ANTHROPIC_KEYCHAIN_SERVICE:-testprep_anthropic_api_key}"
######## END CONFIG #########

[[ "$TRACE" == "1" ]] && set -x

ts() { date +"%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(ts)] $*"; }
die() { echo "[$(ts)] ❌ $*" >&2; exit 1; }

[[ "$TARGET" == "pi" || "$TARGET" == "lightsail" ]] || die "TARGET must be 'pi' or 'lightsail' (got: $TARGET)"

SSH_COMMON_OPTS=(-o StrictHostKeyChecking=no -o ConnectTimeout=10)
[[ "$SSH_VERBOSE" == "1" ]] && SSH_COMMON_OPTS+=(-vvv)

need() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }
need docker
need security
need ssh
need scp
[[ "$TARGET" == "pi" ]] && need sshpass

if ! docker info >/dev/null 2>&1; then
  die "Docker daemon is not running. Please start Docker Desktop."
fi
if ! docker buildx version >/dev/null 2>&1; then
  die "Docker buildx not available. Update Docker to latest version."
fi

log "✅ Prerequisites check passed"
log "🎯 Target: ${TARGET}"

# --- Target-specific defaults ---
if [[ "$TARGET" == "lightsail" ]]; then
  PLATFORMS="${PLATFORMS:-linux/amd64}"
  REMOTE_USER="${LIGHTSAIL_REMOTE_USER}"
  if [[ -n "${LIGHTSAIL_IP:-}" ]]; then
    REMOTE_HOST="${LIGHTSAIL_IP}"
  elif REMOTE_HOST=$(security find-generic-password -s "lightsail_ip" -w 2>/dev/null) && [[ -n "${REMOTE_HOST:-}" ]]; then
    log "🔑 Lightsail IP from Keychain"
  else
    die "Lightsail IP required — set LIGHTSAIL_IP env var or store in Keychain:
    security add-generic-password -s lightsail_ip -a lightsail -w <IP>"
  fi
  [[ -f "$LIGHTSAIL_KEY" ]] || die "SSH key not found: ${LIGHTSAIL_KEY} (set LIGHTSAIL_KEY env var)"
  REMOTE_DIR="${REMOTE_DIR:-/data/test-prep}"
  REMOTE_COMPOSE="${REMOTE_COMPOSE:-${REMOTE_DIR}/docker-compose-lightsail.yml}"
  COMPOSE_LOCAL="docker-compose-lightsail.yml"
else
  PLATFORMS="${PLATFORMS:-linux/arm64}"
  COMPOSE_LOCAL="docker-compose-headless-testprep.yml"
  # REMOTE_DIR / REMOTE_COMPOSE set after SSH (need $HOME from Pi)
fi

# --- SSH/SCP helpers ---
ssh_exec() {
  if [[ "$TARGET" == "lightsail" ]]; then
    ssh "${SSH_COMMON_OPTS[@]}" -i "${LIGHTSAIL_KEY}" "${REMOTE_USER}@${REMOTE_HOST}" "$1"
  else
    sshpass -p "$PASSWORD" ssh "${SSH_COMMON_OPTS[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "$1"
  fi
}

scp_file() {
  if [[ "$TARGET" == "lightsail" ]]; then
    scp "${SSH_COMMON_OPTS[@]}" -i "${LIGHTSAIL_KEY}" "$@"
  else
    sshpass -p "$PASSWORD" scp "${SSH_COMMON_OPTS[@]}" "$@"
  fi
}

ssh_retry() {
  local i=1
  while true; do
    if ssh_exec "$1"; then return 0; fi
    if (( i >= RETRIES )); then return 1; fi
    log "⏳ SSH cmd failed (attempt ${i}/${RETRIES}), retrying in ${SLEEP_BETWEEN}s…"
    sleep "$SLEEP_BETWEEN"
    ((i++))
  done
}

# --- Connectivity setup ---
if [[ "$SKIP_DEPLOY" != "1" ]]; then
  if [[ "$TARGET" == "pi" ]]; then
    log "🔑 Fetching password from keychain service: ${PI_KEYCHAIN_SERVICE}"
    PASSWORD=$(security find-generic-password -s "$PI_KEYCHAIN_SERVICE" -w) || die "Could not read password from Keychain ($PI_KEYCHAIN_SERVICE)."
  fi

  log "📡 Testing SSH connectivity to ${REMOTE_USER}@${REMOTE_HOST}"
  if ! ssh_exec "echo ok" >/dev/null 2>&1; then
    die "SSH connection failed. Check hostname/user/$( [[ "$TARGET" == "pi" ]] && echo 'password' || echo 'key' )."
  fi
  log "✅ SSH connectivity OK"

  if [[ "$TARGET" == "pi" ]]; then
    REMOTE_HOME=$(ssh_exec 'printf %s "$HOME"') || die "Could not determine remote HOME"
    log "🏠 Remote HOME is: ${REMOTE_HOME}"
    REMOTE_DIR="${REMOTE_DIR:-${REMOTE_HOME}/apps/test-prep}"
    REMOTE_COMPOSE="${REMOTE_COMPOSE:-${REMOTE_DIR}/docker-compose-testprep.yml}"
  fi
else
  log "⏭️  Skipping SSH checks (SKIP_DEPLOY=1)"
  if [[ "$TARGET" == "pi" ]]; then
    REMOTE_DIR="${REMOTE_DIR:-/home/${REMOTE_USER}/apps/test-prep}"
    REMOTE_COMPOSE="${REMOTE_COMPOSE:-${REMOTE_DIR}/docker-compose-testprep.yml}"
  fi
fi

# --- Build ---
log "🔧 Setting up docker buildx builder: ${BUILDER_NAME}"
START_BUILDER=$(date +%s)

if docker buildx inspect "${BUILDER_NAME}" >/dev/null 2>&1; then
  log "   Using existing builder: ${BUILDER_NAME}"
  docker buildx use "${BUILDER_NAME}"
else
  log "   Creating new builder: ${BUILDER_NAME}"
  docker buildx create --name "${BUILDER_NAME}" --use
fi

log "✅ Builder ready in $(( $(date +%s) - START_BUILDER ))s"

if [[ "$DOCKER_VERBOSE" == "1" ]]; then
  PROGRESS_MODE="plain"
  log "   Using verbose build output (DOCKER_VERBOSE=1)"
else
  PROGRESS_MODE="auto"
fi

IMAGE_TAR="/tmp/${DOCKER_REPO##*/}-${TAG}.tar"

if [[ "$DIRECT_COPY" == "1" ]]; then
  log "🐳 Building ${DOCKER_REPO}:${TAG} for ${PLATFORMS} (direct copy mode)"
  log "   Will save to: ${IMAGE_TAR}"
else
  log "🐳 Building & pushing ${DOCKER_REPO}:${TAG} for ${PLATFORMS} (Docker Hub mode)"
fi

START_BUILD=$(date +%s)
log "   Platforms: ${PLATFORMS}"
log "   Progress: ${PROGRESS_MODE}"
log ""
log "⏳ Building... (this may take several minutes for multi-arch builds)"

if [[ "$DIRECT_COPY" == "1" ]]; then
  [[ "$PLATFORMS" == *","* ]] && die "DIRECT_COPY mode requires single platform (set PLATFORMS=linux/arm64 or linux/amd64)"
  docker buildx build \
    --platform "${PLATFORMS}" \
    -t "${DOCKER_REPO}:${TAG}" \
    --output type=docker,dest="${IMAGE_TAR}" \
    --progress="${PROGRESS_MODE}" \
    . || die "Docker build failed"
else
  docker buildx build \
    --platform "${PLATFORMS}" \
    -t "${DOCKER_REPO}:${TAG}" \
    --push \
    --progress="${PROGRESS_MODE}" \
    . || die "Docker build failed"
fi

END_BUILD=$(date +%s)
BUILD_TIME=$((END_BUILD - START_BUILD))
log ""
log "✅ Build completed in ${BUILD_TIME}s ($((BUILD_TIME/60))m $((BUILD_TIME%60))s)"
if [[ "$DIRECT_COPY" == "1" ]]; then
  log "   Image saved: ${IMAGE_TAR} ($(du -h "${IMAGE_TAR}" | cut -f1))"
fi

if [[ "$DIRECT_COPY" == "1" && "$PUSH_TO_HUB" == "1" ]]; then
  log ""
  log "📤 Also pushing to Docker Hub (PUSH_TO_HUB=1)..."
  START_PUSH=$(date +%s)
  docker buildx build \
    --platform "${PLATFORMS}" \
    -t "${DOCKER_REPO}:${TAG}" \
    --push \
    --progress="${PROGRESS_MODE}" \
    . || log "⚠️  Push to Docker Hub failed (continuing with direct copy)"
  log "✅ Pushed to Docker Hub in $(($(date +%s) - START_PUSH))s"
fi

if [[ "$SKIP_DEPLOY" == "1" ]]; then
  log ""
  log "🎉 Build complete! (Deployment skipped: SKIP_DEPLOY=1)"
  exit 0
fi

# --- Deploy ---
log ""
log "📡 Deploying to ${TARGET}: ${REMOTE_USER}@${REMOTE_HOST}"
log "📁 Creating remote dir: ${REMOTE_DIR}"
if [[ "$TARGET" == "lightsail" ]]; then
  ssh_retry "sudo mkdir -p '${REMOTE_DIR}' && sudo chown ubuntu:ubuntu '${REMOTE_DIR}'" || die "Could not create ${REMOTE_DIR}."
else
  ssh_retry "mkdir -p '${REMOTE_DIR}'" || die "Could not create ${REMOTE_DIR}."
fi
log "✅ Remote directory ready"

log "📝 Uploading compose: ${COMPOSE_LOCAL} -> ${REMOTE_COMPOSE}"
scp_file "${COMPOSE_LOCAL}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_COMPOSE}" || die "SCP of compose file failed"
log "✅ Compose uploaded"

if [[ -f "${CONFIG_JSON_LOCAL}" ]]; then
  log "🔐 Uploading config.json to ${REMOTE_DIR}/config.json"
  scp_file "${CONFIG_JSON_LOCAL}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/config.json" || die "SCP of config.json failed"
  log "✅ config.json uploaded"
else
  log "⚠️  ${CONFIG_JSON_LOCAL} not found locally — skipping upload."
fi

if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  log "🔑 Using ANTHROPIC_API_KEY from environment"
elif ANTHROPIC_API_KEY=$(security find-generic-password -s "${ANTHROPIC_KEYCHAIN_SERVICE}" -w 2>/dev/null) && [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  log "🔑 Claude API key from Keychain (${ANTHROPIC_KEYCHAIN_SERVICE})"
fi

if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  log "🔑 Creating .env file with ANTHROPIC_API_KEY"
  TEMP_ENV_FILE=$(mktemp)
  echo "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}" > "${TEMP_ENV_FILE}"
  scp_file "${TEMP_ENV_FILE}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/.env" || die "SCP of .env failed"
  rm -f "${TEMP_ENV_FILE}"
  log "✅ .env uploaded"
else
  log "⚠️  ANTHROPIC_API_KEY not set — app will not be able to use Claude API"
  log "    Set it before running (export ANTHROPIC_API_KEY=sk-ant-...) or store it in Keychain:"
  log "    security add-generic-password -s ${ANTHROPIC_KEYCHAIN_SERVICE} -a \"\$USER\" -w sk-ant-..."
fi

log "📊 Ensuring analytics.json exists..."
ssh_retry "touch '${REMOTE_DIR}/analytics.json'" || log "⚠️  Could not create analytics.json"
log "✅ Analytics file ready"

if [[ "$DIRECT_COPY" == "1" ]]; then
  log ""
  log "🚀 Transferring Docker image to ${TARGET}..."
  START_TRANSFER=$(date +%s)

  REMOTE_TAR="${REMOTE_DIR}/image.tar"
  log "📦 Copying image tar: ${IMAGE_TAR} -> ${REMOTE_TAR}"
  scp_file "${IMAGE_TAR}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_TAR}" || die "SCP of image tar failed"

  TRANSFER_TIME=$(($(date +%s) - START_TRANSFER))
  log "✅ Image transferred in ${TRANSFER_TIME}s ($((TRANSFER_TIME/60))m $((TRANSFER_TIME%60))s)"

  log "📥 Loading image on ${TARGET}..."
  START_LOAD=$(date +%s)
  ssh_retry "docker load -i '${REMOTE_TAR}'" || die "docker load failed"
  log "✅ Image loaded in $(($(date +%s) - START_LOAD))s"

  log "🧹 Cleaning up tar files..."
  ssh_retry "rm -f '${REMOTE_TAR}'" || log "⚠️  Could not remove remote tar"
  rm -f "${IMAGE_TAR}" || log "⚠️  Could not remove local tar"

  log "🔁 Starting service..."
  ssh_retry "cd '${REMOTE_DIR}' && docker compose -f '${REMOTE_COMPOSE}' up -d" || die "docker compose up failed"
  log "✅ Service started"
else
  log ""
  log "🔁 Pulling image from Docker Hub and restarting service..."
  ssh_retry "cd '${REMOTE_DIR}' && docker compose -f '${REMOTE_COMPOSE}' pull && docker compose -f '${REMOTE_COMPOSE}' up -d" || die "docker compose pull/up failed"
  log "✅ Service updated"
fi

# Health check
if [[ "$TARGET" == "pi" ]]; then
  URL="http://${REMOTE_HOST}:8789"
  log "🩺 Health check: ${URL}"
  if ssh_exec "wget -qO- '${URL}' >/dev/null"; then
    log "✅ App responds at ${URL}"
  else
    log "⚠️  Could not GET ${URL}. Services may still be starting."
  fi
else
  log "🩺 Checking containers on Lightsail..."
  if ssh_exec "docker ps --filter name=test-prep --format '{{.Names}} {{.Status}}'" 2>/dev/null | grep -q "Up"; then
    log "✅ Container is running"
  else
    log "⚠️  Container may not be up yet — check: ssh -i ${LIGHTSAIL_KEY} ubuntu@${REMOTE_HOST} docker ps"
  fi
fi

# Summary
TOTAL_TIME=$(($(date +%s) - START_BUILD))
log ""
log "🎉 Deployment complete!"
log ""
log "Summary:"
log "  • Image: ${DOCKER_REPO}:${TAG}"
log "  • Target: ${TARGET}"
log "  • Platforms: ${PLATFORMS}"
if [[ "$DIRECT_COPY" == "1" ]]; then
  log "  • Method: Direct copy (tar transfer)"
  [[ -n "${TRANSFER_TIME:-}" ]] && log "  • Transfer time: ${TRANSFER_TIME}s ($((TRANSFER_TIME/60))m $((TRANSFER_TIME%60))s)"
  [[ "$PUSH_TO_HUB" == "1" ]] && log "  • Also pushed to Docker Hub: Yes"
else
  log "  • Method: Docker Hub (registry pull)"
fi
log "  • Build time: ${BUILD_TIME}s ($((BUILD_TIME/60))m $((BUILD_TIME%60))s)"
log "  • Total time: ${TOTAL_TIME}s ($((TOTAL_TIME/60))m $((TOTAL_TIME%60))s)"
log "  • Remote: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}"
[[ "$TARGET" == "pi" ]] && log "  • URL: http://${REMOTE_HOST}:8789"
log ""
