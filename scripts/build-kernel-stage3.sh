#!/bin/bash
set -e

echo "==> Stage 3: Compiling kernel"

# Compiler selection (default: gcc)
COMPILER=${COMPILER:-gcc}
echo "    COMPILER: ${COMPILER}"

# Repository root (for both Docker and local builds)
REPO_ROOT=${REPO_ROOT:-/repo}
if [ ! -d "$REPO_ROOT" ]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
echo "    Repository root: ${REPO_ROOT}"

# Work directory
WORK_DIR=${WORK_DIR:-/src}
cd "$WORK_DIR/pve-kernel"
echo "    Working directory: ${WORK_DIR}/pve-kernel"

# Extract kernel version from Makefile
KERNEL_MAJ=$(grep "^KERNEL_MAJ=" Makefile | cut -d'=' -f2)
KERNEL_MIN=$(grep "^KERNEL_MIN=" Makefile | cut -d'=' -f2)
KERNEL_PATCHLEVEL=$(grep "^KERNEL_PATCHLEVEL=" Makefile | cut -d'=' -f2)
KREL=$(grep "^KREL=" Makefile | cut -d'=' -f2)
KERNEL_VERSION="${KERNEL_MAJ}.${KERNEL_MIN}.${KERNEL_PATCHLEVEL}-${KREL}"
echo "    Kernel version: ${KERNEL_VERSION}"

# Build
if [ "$COMPILER" = "clang" ]; then
  echo "==> Building kernel packages with clang (this may take 30-60 minutes)"
  make LLVM=1 deb
else
  echo "==> Building kernel packages with gcc (this may take 30-60 minutes)"
  make deb
fi

echo "==> Build complete!"
echo "    Kernel version: ${KERNEL_VERSION}"
echo "    Packages built:"
ls -lh ../*.deb 2>/dev/null || ls -lh ./*.deb 2>/dev/null || echo "    (packages in unknown location)"

# Copy packages to repository root
if [ -d "$REPO_ROOT" ]; then
  echo "==> Copying packages to $REPO_ROOT"
  cp ../*.deb "$REPO_ROOT/" 2>/dev/null || cp ./*.deb "$REPO_ROOT/" 2>/dev/null || echo "    Warning: Could not copy packages"
  ls -lh "$REPO_ROOT"/*.deb 2>/dev/null
fi

echo "==> Stage 3 complete!"
