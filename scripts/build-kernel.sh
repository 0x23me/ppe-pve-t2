#!/bin/bash
set -e

# Environment variables (passed from workflow):
# - PVE_KERNEL_TAG: e.g., "proxmox-kernel-7.0.14-26" (optional; default: newest buildable)
# - T2LINUX_COMMIT: e.g., "699c8fdf6e5d0c3bbd3487960df42881d4e8ffd9"

echo "==> Building PVE kernel with T2 support"
echo "    T2LINUX_COMMIT: ${T2LINUX_COMMIT}"

# Compiler selection (default: gcc)
COMPILER=${COMPILER:-gcc}
echo "    COMPILER: ${COMPILER}"

# Repository root (for both Docker and local builds)
REPO_ROOT=${REPO_ROOT:-/repo}
if [ ! -d "$REPO_ROOT" ]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
echo "    Repository root: ${REPO_ROOT}"

# Detect if running in Docker (check if /repo is mounted and different from auto-detected path)
IN_DOCKER=0
if [ "$REPO_ROOT" = "/repo" ] && [ -d "/repo" ]; then
  IN_DOCKER=1
fi

# Work directory: persistent for local builds, ephemeral for Docker
if [ "$IN_DOCKER" = "1" ]; then
  WORK_DIR="/tmp/pve-build-$$"
  echo "    Build environment: Docker (ephemeral)"
else
  WORK_DIR="/tmp/pve-build-local"
  echo "    Build environment: Local (persistent cache)"
fi

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"
echo "    Working directory: ${WORK_DIR}"

# Install basic tools
echo "==> Installing basic tools"
apt-get update -qq
apt-get install -y -qq wget curl ca-certificates git

# Add Proxmox repository
echo "==> Adding Proxmox repository"
mkdir -p /usr/share/keyrings
echo "    Downloading Proxmox GPG key..."
wget -v https://enterprise.proxmox.com/debian/proxmox-archive-keyring-trixie.gpg -O /usr/share/keyrings/proxmox-archive-keyring.gpg || {
  echo "    ERROR: Failed to download Proxmox GPG key"
  echo "    Trying alternative method..."
  curl -f https://enterprise.proxmox.com/debian/proxmox-archive-keyring-trixie.gpg -o /usr/share/keyrings/proxmox-archive-keyring.gpg
}
echo "    Adding Proxmox repository to sources..."
echo "deb [signed-by=/usr/share/keyrings/proxmox-archive-keyring.gpg] http://download.proxmox.com/debian/pve trixie pve-no-subscription" > /etc/apt/sources.list.d/pve.list
echo "    Proxmox repository added successfully"

# Install build dependencies
echo "==> Installing build dependencies"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
  build-essential git bc bison flex libssl-dev libelf-dev \
  asciidoc-base automake cpio debhelper dh-python file gcc kmod \
  libdw-dev libiberty-dev libnuma-dev libslang2-dev libtool \
  lintian lz4 dwarves python3-dev zstd \
  perl-modules rsync sphinx-common xmlto zlib1g-dev gawk \
  clang lld llvm

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
# PVE_KERNEL_TAG is e.g. "proxmox-kernel-7.0.14-26" (from check-versions.sh);
# without it, pick the newest buildable release ourselves.
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
echo "    t2linux KVER: ${T2_KVER}"
echo "    Packages built:"
ls -lh ../*.deb 2>/dev/null || ls -lh ./*.deb 2>/dev/null || echo "    (packages in unknown location)"

# Copy packages to repository root
if [ -d "$REPO_ROOT" ]; then
  echo "==> Copying packages to $REPO_ROOT"
  cp ../*.deb "$REPO_ROOT/" 2>/dev/null || cp ./*.deb "$REPO_ROOT/" 2>/dev/null || echo "    Warning: Could not copy packages"
  ls -lh "$REPO_ROOT"/*.deb 2>/dev/null
fi
