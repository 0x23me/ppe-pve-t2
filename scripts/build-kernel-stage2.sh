#!/bin/bash
set -e

echo "==> Stage 2: Cloning repositories and preparing patches"

# Environment variables (passed from workflow):
# - T2LINUX_COMMIT: e.g., "699c8fdf6e5d0c3bbd3487960df42881d4e8ffd9"

echo "    T2LINUX_COMMIT: ${T2LINUX_COMMIT}"

# Repository root (for both Docker and local builds)
REPO_ROOT=${REPO_ROOT:-/repo}
if [ ! -d "$REPO_ROOT" ]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
echo "    Repository root: ${REPO_ROOT}"

# Work directory
WORK_DIR=${WORK_DIR:-/src}
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"
echo "    Working directory: ${WORK_DIR}"

# Clone or update t2linux patches
if [ -d "linux-t2-patches/.git" ]; then
  echo "==> Updating existing t2linux patches repository"
  cd linux-t2-patches
  git fetch origin
else
  echo "==> Cloning t2linux patches"
  git clone https://github.com/t2linux/linux-t2-patches.git
  cd linux-t2-patches
fi

git checkout "$T2LINUX_COMMIT"
T2_KVER=$(cat version 2>/dev/null || echo "unknown")
echo "    Using t2linux commit: ${T2LINUX_COMMIT}"
echo "    t2linux KVER: ${T2_KVER}"
cd ..

# Clone or update pve-kernel
if [ -d "pve-kernel/.git" ]; then
  echo "==> Updating existing pve-kernel repository"
  cd pve-kernel
  git am --abort 2>/dev/null || true
  git fetch origin
  git reset --hard origin/master
  git clean -fdx
else
  echo "==> Cloning pve-kernel repository"
  git clone git://git.proxmox.com/git/pve-kernel.git
  cd pve-kernel
fi

# Check out the requested release instead of the tip of master: master can
# reference a zfsonlinux commit that isn't published yet.
# PVE_KERNEL_TAG is e.g. "proxmox-kernel-7.0.14-26"; without it, pick the
# newest buildable release ourselves.
PVE_VERSION="${PVE_KERNEL_TAG#proxmox-kernel-}"
if [ -z "$PVE_KERNEL_TAG" ] || [ "$PVE_VERSION" = "$PVE_KERNEL_TAG" ]; then
  PVE_VERSION=$(bash "$REPO_ROOT/scripts/find-pve-commit.sh" | sed -n 's/.*"version": "\([^"]*\)".*/\1/p')
fi
PVE_COMMIT=$(git log --format=%H -1 --grep="^bump version to ${PVE_VERSION}\$" origin/master)
if [ -z "$PVE_COMMIT" ]; then
  echo "    ERROR: no 'bump version to ${PVE_VERSION}' commit on pve-kernel master"
  exit 1
fi
echo "==> Checking out pve-kernel ${PVE_VERSION} (${PVE_COMMIT})"
git checkout --quiet --detach "$PVE_COMMIT"

# Extract kernel version from Makefile
KERNEL_MAJ=$(grep "^KERNEL_MAJ=" Makefile | cut -d'=' -f2)
KERNEL_MIN=$(grep "^KERNEL_MIN=" Makefile | cut -d'=' -f2)
KERNEL_PATCHLEVEL=$(grep "^KERNEL_PATCHLEVEL=" Makefile | cut -d'=' -f2)
KREL=$(grep "^KREL=" Makefile | cut -d'=' -f2)
KERNEL_VERSION="${KERNEL_MAJ}.${KERNEL_MIN}.${KERNEL_PATCHLEVEL}-${KREL}"
echo "    Kernel version: ${KERNEL_VERSION}"

# Copy t2linux patches to kernel patches directory
echo "==> Copying t2linux patches to pve-kernel"
mkdir -p patches/kernel
cp ../linux-t2-patches/*.patch ./patches/kernel/

# Replace t2linux patches that don't apply to Proxmox's Ubuntu-based source
# with rebased versions from patches/t2-overrides/<major.minor>/ (same file name)
OVERRIDE_DIR="$REPO_ROOT/patches/t2-overrides/${KERNEL_MAJ}.${KERNEL_MIN}"
if [ -d "$OVERRIDE_DIR" ]; then
  for p in "$OVERRIDE_DIR"/*.patch; do
    [ -e "$p" ] || continue
    echo "    Using rebased override: $(basename "$p")"
    cp "$p" ./patches/kernel/
  done
fi

# Copy our T2.patch (build system modifications)
echo "==> Applying T2.patch (build system modifications)"
cp "$REPO_ROOT/patches/T2.patch" ./

# Apply T2.patch to modify Makefile and debian/rules
git config user.email "build@0x23me.github.io"
git config user.name "Build Bot"
git am T2.patch

# Initialize submodules (only if not already initialized)
if [ ! -d "submodules/ubuntu-kernel/.git" ] || [ ! -d "submodules/zfsonlinux/.git" ]; then
  echo "==> Initializing submodules"
  git submodule update --depth 1 --init submodules/ubuntu-kernel
  git submodule update --init --recursive submodules/zfsonlinux
else
  echo "==> Submodules already initialized, skipping"
fi

echo "==> Stage 2 complete!"
echo "    Kernel version: ${KERNEL_VERSION}"
echo "    t2linux KVER: ${T2_KVER}"
