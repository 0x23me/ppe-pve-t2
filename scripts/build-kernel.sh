#!/bin/bash
set -e

# Environment variables (passed from workflow):
# - PVE_KERNEL_TAG: e.g., "pve-kernel-6.17.4-2"
# - T2LINUX_COMMIT: e.g., "699c8fdf6e5d0c3bbd3487960df42881d4e8ffd9"

echo "==> Building PVE kernel with T2 support"
echo "    T2LINUX_COMMIT: ${T2LINUX_COMMIT}"

# Work in /tmp to avoid conflicts with mounted volumes
WORK_DIR="/tmp/pve-build-$$"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"
echo "    Working directory: ${WORK_DIR}"

# Install basic tools and nala
echo "==> Installing nala and basic tools"
apt-get update -qq
apt-get install -y -qq nala wget curl ca-certificates git

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
nala update
nala install -y \
  build-essential git bc bison flex libssl-dev libelf-dev \
  asciidoc-base automake cpio debhelper dh-python file gcc kmod \
  libdw-dev libiberty-dev libnuma-dev libslang2-dev libtool \
  lintian lz4 dwarves python3-dev zstd \
  perl-modules rsync sphinx-common xmlto zlib1g-dev gawk

# Clone t2linux patches at specified commit (fetched dynamically)
echo "==> Cloning t2linux patches at commit ${T2LINUX_COMMIT}"
git clone https://github.com/t2linux/linux-t2-patches.git
cd linux-t2-patches
git checkout "$T2LINUX_COMMIT"
T2_KVER=$(cat version 2>/dev/null || echo "unknown")
echo "    t2linux KVER: ${T2_KVER}"
cd ..

# Clone pve-kernel (uses master/latest)
echo "==> Cloning pve-kernel repository"
git clone git://git.proxmox.com/git/pve-kernel.git
cd pve-kernel

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
cp /repo/patches/T2.patch ./

# Apply T2.patch to modify Makefile and debian/rules
git config user.email "build@0x23me.github.io"
git config user.name "Build Bot"
git am T2.patch

# Initialize submodules
echo "==> Initializing submodules"
git submodule update --depth 1 --init submodules/ubuntu-kernel
git submodule update --init --recursive submodules/zfsonlinux

# Build
echo "==> Building kernel packages (this may take 30-60 minutes)"
make deb

echo "==> Build complete!"
echo "    Kernel version: ${KERNEL_VERSION}"
echo "    t2linux KVER: ${T2_KVER}"
echo "    Packages built:"
ls -lh ../*.deb 2>/dev/null || ls -lh ./*.deb 2>/dev/null || echo "    (packages in unknown location)"

# Copy packages to /repo if it exists (for Docker builds)
if [ -d "/repo" ]; then
  echo "==> Copying packages to /repo"
  cp ../*.deb /repo/ 2>/dev/null || cp ./*.deb /repo/ 2>/dev/null || echo "    Warning: Could not copy packages"
  ls -lh /repo/*.deb 2>/dev/null
fi
