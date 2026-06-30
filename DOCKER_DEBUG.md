# Docker Build Debugging Guide

If you're experiencing issues with the Docker build script, especially slow or hanging builds, use this guide to debug.

## ⚡ Quick Fix: Use Direct Copy (Default)

The script now **defaults to DIRECT_COPY mode** which is **much faster**:
- Builds the image locally
- Saves as a tar file
- Copies directly to Pi over local network (fast!)
- Loads on the Pi

**No more slow Docker Hub uploads!**

## Deployment Methods

### 1. Direct Copy (Default, Recommended) ⚡
```bash
./docker-build-testprep.sh                    # Default: Direct copy to Pi
PUSH_TO_HUB=1 ./docker-build-testprep.sh      # Also backup to Docker Hub
```
- **Fastest**: Transfers over local network
- **Simple**: One command does everything
- **Reliable**: No Docker Hub rate limits or network issues

### 2. Docker Hub Method (Legacy)
```bash
DIRECT_COPY=0 ./docker-build-testprep.sh      # Use old Docker Hub method
```
- **Slower**: Upload to Hub, then Pi downloads
- **Use case**: When Pi is not on local network

## Quick Diagnosis

### Issue: Build hangs at "exporting to image" or "pushing layers"

This was the old Docker Hub method. **Solution**: Use the new default DIRECT_COPY=1 mode (already default).

### Solutions

#### 1. Enable Verbose Output

See exactly what Docker is doing:

```bash
DOCKER_VERBOSE=1 ./docker-build-testprep.sh
```

This shows detailed build progress including layer caching, download progress, and export status.

#### 2. Build for Single Platform (Faster Testing)

If you only need the image for Raspberry Pi:

```bash
PLATFORMS=linux/arm64 ./docker-build-testprep.sh
```

This is **much faster** than building for both amd64 and arm64.

#### 3. Local Build Only (No Push)

Test the build without pushing to Docker Hub:

```bash
SKIP_DEPLOY=1 SKIP_PUSH=1 ./docker-build-testprep.sh
```

**Note**: `--load` only works with single platform. If you get an error, combine with `PLATFORMS`:

```bash
SKIP_DEPLOY=1 SKIP_PUSH=1 PLATFORMS=linux/arm64 ./docker-build-testprep.sh
```

#### 4. Build & Push Without Deploy

Build and push to registry but skip Raspberry Pi deployment:

```bash
SKIP_DEPLOY=1 ./docker-build-testprep.sh
```

#### 5. Full Bash Debug Trace

See every command executed:

```bash
TRACE=1 ./docker-build-testprep.sh
```

## Common Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DIRECT_COPY` | 1 | `1` = Copy image directly to Pi (fast), `0` = Use Docker Hub |
| `PUSH_TO_HUB` | 0 | Set to `1` to also push to Docker Hub (works with DIRECT_COPY=1) |
| `PLATFORMS` | `linux/arm64` | Comma-separated platforms. Use `linux/amd64,linux/arm64` for multi-arch |
| `DOCKER_VERBOSE` | 0 | Set to `1` for detailed Docker build output |
| `SKIP_DEPLOY` | 0 | Set to `1` to skip Pi deployment (build only) |
| `TRACE` | 0 | Set to `1` for bash debug mode (full command trace) |
| `BUILDER_NAME` | `testprep-builder` | Name of buildx builder instance |
| `DOCKER_REPO` | `iqesolutions/test-prep` | Docker Hub repository |
| `TAG` | `latest` | Image tag |

## Example Workflows

### Normal Deployment (Fastest) ⚡

```bash
# Default: Build locally, copy directly to Pi
./docker-build-testprep.sh

# With verbose output
DOCKER_VERBOSE=1 ./docker-build-testprep.sh
```

### Backup to Docker Hub

```bash
# Direct copy to Pi + push to Docker Hub for backup
PUSH_TO_HUB=1 ./docker-build-testprep.sh
```

### Test Build Only

```bash
# Build without deploying to Pi
SKIP_DEPLOY=1 ./docker-build-testprep.sh
```

### Old Docker Hub Method (Slow)

```bash
# Use Docker Hub instead of direct copy (slower)
DIRECT_COPY=0 ./docker-build-testprep.sh
```

### Debug Build Issues

```bash
# Maximum verbosity
DOCKER_VERBOSE=1 TRACE=1 ./docker-build-testprep.sh
```

### Multi-Architecture Build

```bash
# Build for multiple platforms (takes longer)
# Note: DIRECT_COPY only works with single platform
PLATFORMS=linux/amd64,linux/arm64 DIRECT_COPY=0 ./docker-build-testprep.sh
```

## Inspecting Your Builder

Check builder status:

```bash
docker buildx ls
```

Inspect specific builder:

```bash
docker buildx inspect testprep-builder
```

Remove and recreate builder:

```bash
docker buildx rm testprep-builder
./docker-build-testprep.sh
```

## Understanding Build Times

### Direct Copy Mode (Default) ⚡

Typical times for DIRECT_COPY=1:
- **Build**: 10-30 seconds (with cache)
- **Transfer to Pi**: 10-30 seconds (depends on network speed)
- **Load on Pi**: 5-10 seconds
- **Total**: 30-70 seconds

### Docker Hub Mode (Legacy)

Typical times for DIRECT_COPY=0:
- **Single platform** (arm64 only): 2-5 minutes
- **Multi-platform** (amd64 + arm64): 5-15 minutes
- **Push to Hub**: 2-5 minutes (depends on upload speed)
- **Pi pulls from Hub**: 1-3 minutes
- **Total**: 5-20 minutes

**Direct Copy is 5-10x faster!**

## Still Stuck?

1. **Check Docker Desktop is running**:
   ```bash
   docker info
   ```

2. **Check Docker version** (need buildx):
   ```bash
   docker version
   docker buildx version
   ```

3. **Check available disk space**:
   ```bash
   df -h
   docker system df
   ```

4. **Prune Docker cache** (if desperate):
   ```bash
   docker buildx prune -af
   ```

5. **Restart Docker Desktop**

6. **Check Docker Hub login**:
   ```bash
   docker login
   ```

## Performance Tips

1. **Use single platform for testing**: `PLATFORMS=linux/arm64`
2. **Skip push when testing**: `SKIP_PUSH=1`
3. **Keep builder running**: Don't remove it between builds
4. **Use SSD**: Docker builds are I/O intensive
5. **Allocate more resources** to Docker Desktop (Settings → Resources)

## Example: Complete Debug Session

```bash
# Step 1: Check everything is working
docker info
docker buildx ls

# Step 2: Try fast local build first
DOCKER_VERBOSE=1 SKIP_DEPLOY=1 SKIP_PUSH=1 PLATFORMS=linux/arm64 ./docker-build-testprep.sh

# Step 3: If that works, try with push
DOCKER_VERBOSE=1 SKIP_DEPLOY=1 PLATFORMS=linux/arm64 ./docker-build-testprep.sh

# Step 4: If that works, try full deployment
DOCKER_VERBOSE=1 PLATFORMS=linux/arm64 ./docker-build-testprep.sh

# Step 5: If everything works, do full multi-arch
./docker-build-testprep.sh
```

This incremental approach helps identify exactly where the problem is!
