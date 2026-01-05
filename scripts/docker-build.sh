#!/bin/bash
set -e

# Helper script for building PVE kernel with T2 support using Docker
# Usage: ./scripts/docker-build.sh [T2LINUX_COMMIT] [COMPILER]
#
# Example:
#   ./scripts/docker-build.sh 699c8fdf6e5d0c3bbd3487960df42881d4e8ffd9 gcc

# Get repository root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Default values
T2LINUX_COMMIT=${1:-699c8fdf6e5d0c3bbd3487960df42881d4e8ffd9}
COMPILER=${2:-gcc}

echo "==> Building PVE kernel with Docker"
echo "    Repository root: ${REPO_ROOT}"
echo "    T2LINUX_COMMIT: ${T2LINUX_COMMIT}"
echo "    COMPILER: ${COMPILER}"

# Build the Docker image (stages 1 & 2 run during build)
echo "==> Building Docker image (this will clone repos and prepare patches)..."
docker build \
  --build-arg T2LINUX_COMMIT="${T2LINUX_COMMIT}" \
  -t pve-kernel-builder \
  .

# Run the container to compile (stage 3)
# Only mount /repo to capture output .deb files
echo "==> Running compilation container (stage 3) with ${COMPILER}..."
docker run --rm \
  -v "${REPO_ROOT}:/repo" \
  -e COMPILER="${COMPILER}" \
  -e REPO_ROOT=/repo \
  -e WORK_DIR=/src \
  pve-kernel-builder

echo "==> Build complete!"
echo "    Kernel packages: ${REPO_ROOT}/*.deb"
ls -lh "${REPO_ROOT}"/*.deb 2>/dev/null || echo "    (no .deb files found)"
