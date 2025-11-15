#!/bin/bash
# docker-build-testprep.sh — build multi-arch, push, and deploy to Raspberry Pi (packs baked in image)

set -euo pipefail

########## CONFIG ##########
DOCKER_REPO="${DOCKER_REPO:-iqesolutions/test-prep}"  # e.g. magnusjohansson/test-prep
TAG="${TAG:-latest}"

REMOTE_USER="${REMOTE_USER:-magnusjohansson}"
REMOTE_HOST="${REMOTE_HOST:-raspberrypi.local}"

KEYCHAIN_SERVICE="${KEYCHAIN_SERVICE:-raspberrypi_scp}"

# Verbosity
TRACE="${TRACE:-0}"             # TRACE=1 for bash -x
SSH_VERBOSE="${SSH_VERBOSE:-0}" # SSH_VERBOSE=1 adds -vvv to ssh/scp
RETRIES="${RETRIES:-3}"
SLEEP_BETWEEN="${SLEEP_BETWEEN:-2}"

# Files to upload
HEADLESS_COMPOSE_LOCAL="${HEADLESS_COMPOSE_LOCAL:-docker-compose-headless-testprep.yml}"
CONFIG_JSON_LOCAL="${CONFIG_JSON_LOCAL:-config.json}"
######## END CONFIG #########

[[ "$TRACE" == "1" ]] && set -x

ts() { date +"%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(ts)] $*"; }
die() { echo "[$(ts)] ❌ $*" >&2; exit 1; }

SSH_COMMON_OPTS=(-o StrictHostKeyChecking=no -o ConnectTimeout=10)
[[ "$SSH_VERBOSE" == "1" ]] && SSH_COMMON_OPTS+=(-vvv)

need() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }
need docker
need security
need sshpass
need ssh
need scp

# Get password from Keychain
log "🔑 Fetching password from keychain service: ${KEYCHAIN_SERVICE}"
PASSWORD=$(security find-generic-password -s "$KEYCHAIN_SERVICE" -w) || die "Could not read password from Keychain ($KEYCHAIN_SERVICE)."

# SSH check
log "📡 Testing SSH connectivity to ${REMOTE_USER}@${REMOTE_HOST}"
if ! sshpass -p "$PASSWORD" ssh "${SSH_COMMON_OPTS[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "echo ok" >/dev/null 2>&1; then
  die "SSH connection failed. Check hostname/user/password."
fi
log "✅ SSH connectivity OK"

# Determine remote HOME
REMOTE_HOME=$(sshpass -p "$PASSWORD" ssh "${SSH_COMMON_OPTS[@]}" "${REMOTE_USER}@${REMOTE_HOST}" 'printf %s "$HOME"') || die "Could not determine remote HOME"
log "🏠 Remote HOME is: ${REMOTE_HOME}"

# Deployment dir
REMOTE_DIR="${REMOTE_DIR:-${REMOTE_HOME}/apps/test-prep}"
REMOTE_COMPOSE="${REMOTE_COMPOSE:-${REMOTE_DIR}/docker-compose-testprep.yml}"

# Build & push
log "🔧 Ensuring docker buildx builder"
docker buildx create --use --name testprep-builder >/dev/null 2>&1 || true

log "🐳 Building & pushing ${DOCKER_REPO}:${TAG} for linux/amd64,linux/arm64"
START_BUILD=$(date +%s)
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t "${DOCKER_REPO}:${TAG}" \
  --push \
  .
END_BUILD=$(date +%s)
log "✅ Build+push done in $((END_BUILD-START_BUILD))s"

# Helper to retry SSH
ssh_retry() {
  local i=1
  while true; do
    if sshpass -p "$PASSWORD" ssh "${SSH_COMMON_OPTS[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "$1"; then
      return 0
    fi
    if (( i >= RETRIES )); then
      return 1
    fi
    log "⏳ SSH cmd failed (attempt ${i}/${RETRIES}), retrying in ${SLEEP_BETWEEN}s…"
    sleep "$SLEEP_BETWEEN"
    ((i++))
  done
}

# Prepare remote dir
log "📁 Creating remote dir on Pi: ${REMOTE_DIR}"
ssh_retry "mkdir -p '${REMOTE_DIR}'" || die "Could not create ${REMOTE_DIR} on the Pi."
log "✅ Remote directory ready"

# Upload compose
log "📝 Uploading compose: ${HEADLESS_COMPOSE_LOCAL} -> ${REMOTE_COMPOSE}"
sshpass -p "$PASSWORD" scp "${SSH_COMMON_OPTS[@]}" "${HEADLESS_COMPOSE_LOCAL}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_COMPOSE}" || die "SCP of compose file failed"
log "✅ Compose uploaded"

# Upload config.json
if [[ -f "${CONFIG_JSON_LOCAL}" ]]; then
  log "🔐 Uploading config.json to ${REMOTE_DIR}/config.json"
  sshpass -p "$PASSWORD" scp "${SSH_COMMON_OPTS[@]}" "${CONFIG_JSON_LOCAL}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/config.json" || die "SCP of config.json failed"
  log "✅ config.json uploaded"
else
  log "⚠️  ${CONFIG_JSON_LOCAL} not found locally — skipping upload."
fi

# Create and upload .env file with OPENAI_API_KEY
if [[ -n "${OPENAI_API_KEY}" ]]; then
  log "🔑 Creating .env file with OPENAI_API_KEY from environment"
  TEMP_ENV_FILE=$(mktemp)
  echo "OPENAI_API_KEY=${OPENAI_API_KEY}" > "${TEMP_ENV_FILE}"

  log "📤 Uploading .env to ${REMOTE_DIR}/.env"
  sshpass -p "$PASSWORD" scp "${SSH_COMMON_OPTS[@]}" "${TEMP_ENV_FILE}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/.env" || die "SCP of .env failed"

  # Clean up temp file
  rm -f "${TEMP_ENV_FILE}"
  log "✅ .env uploaded"
else
  log "⚠️  OPENAI_API_KEY not set in environment — app will not be able to use OpenAI API"
  log "    Set it before running: export OPENAI_API_KEY=sk-..."
fi

# Start/Restart on Pi
log "🔁 Pulling image and restarting service on Pi"
ssh_retry "cd '${REMOTE_DIR}' && docker compose -f '${REMOTE_COMPOSE}' pull && docker compose -f '${REMOTE_COMPOSE}' up -d" || die "docker compose pull/up failed on Pi"
log "✅ Service updated"

# Health check
URL="http://${REMOTE_HOST}:8789"
log "🩺 Health check: ${URL}"
if sshpass -p "$PASSWORD" ssh "${SSH_COMMON_OPTS[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "wget -qO- '${URL}' >/dev/null"; then
  log "✅ App responds at ${URL}"
else
  log "⚠️  Could not GET ${URL}. If using host networking, try http://${REMOTE_HOST}:8787"
fi

log "🎉 Done."