#!/bin/bash
set -e

echo "==> Stage 1: Installing packages and dependencies"

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
  clang lld llvm \
  bindgen rustc rust-src rustfmt rust-clippy

echo "==> Stage 1 complete!"
