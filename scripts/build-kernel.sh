#!/bin/bash
set -e

# Environment variables (passed from workflow):
# - PVE_KERNEL_TAG: e.g., "pve-kernel-6.17.4-2"
# - T2LINUX_COMMIT: e.g., "699c8fdf6e5d0c3bbd3487960df42881d4e8ffd9"

echo "==> Building PVE kernel with T2 support"
echo "    PVE_KERNEL_TAG: ${PVE_KERNEL_TAG}"
echo "    T2LINUX_COMMIT: ${T2LINUX_COMMIT}"

# Add Proxmox repository
echo "==> Adding Proxmox repository"
echo "deb http://download.proxmox.com/debian/pve trixie pve-no-subscription" > /etc/apt/sources.list.d/pve.list
wget -qO /etc/apt/trusted.gpg.d/proxmox.gpg http://download.proxmox.com/debian/proxmox-release-trixie.gpg

# Install build dependencies
echo "==> Installing build dependencies"
apt-get update
apt-get install -y \
  build-essential git bc bison flex libssl-dev libelf-dev \
  asciidoc automake cpio debhelper dh-python file gcc kmod \
  libdw-dev libiberty-dev libnuma-dev libslang2-dev libtool \
  lintian lz4 dwarves libpve-common-perl python3-dev zstd \
  perl-modules rsync sphinx-common xmlto zlib1g-dev gawk

# Clone t2linux patches at specified commit (fetched dynamically)
echo "==> Cloning t2linux patches at commit ${T2LINUX_COMMIT}"
git clone https://github.com/t2linux/linux-t2-patches.git
cd linux-t2-patches
git checkout "$T2LINUX_COMMIT"
T2_KVER=$(cat version 2>/dev/null || echo "unknown")
echo "    t2linux KVER: ${T2_KVER}"
cd ..

# Clone pve-kernel at specific tag
echo "==> Cloning pve-kernel at tag ${PVE_KERNEL_TAG}"
git clone --depth 1 --branch "$PVE_KERNEL_TAG" git://git.proxmox.com/git/pve-kernel.git
cd pve-kernel

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
echo "    t2linux KVER: ${T2_KVER}"
echo "    Packages built:"
ls -lh ../*.deb 2>/dev/null || ls -lh ./*.deb 2>/dev/null || echo "    (packages in unknown location)"
