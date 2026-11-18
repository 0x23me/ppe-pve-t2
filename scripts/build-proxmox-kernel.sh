#!/bin/bash
set -e

# Build from proxmox-kernel.git, where Proxmox keeps the kernel since 7.3: a mainline tree
# (tag v7.3.5) plus debian/, with Proxmox's patches as a quilt series in debian/patches,
# built with git-buildpackage. pve-kernel.git (7.0 and older) is built by build-kernel.sh.
#
# Called by build-kernel.sh, with linux-t2-patches already checked out in WORK_DIR.
# - PVE_KERNEL_TAG: a release tag of proxmox-kernel.git, e.g. "proxmox/7.3.5-1"
# - WORK_DIR, REPO_ROOT: as in build-kernel.sh

PROXMOX_KERNEL_URL="git://git.proxmox.com/git/proxmox-kernel.git"
cd "$WORK_DIR"

# Fetch only the release and the upstream tag gbp makes the orig tarball from, not the
# whole kernel history
echo "==> Fetching proxmox-kernel ${PVE_KERNEL_TAG}"
[ -d proxmox-kernel/.git ] || git init --quiet proxmox-kernel
cd proxmox-kernel
git config user.email "build@0x23me.github.io"
git config user.name "Build Bot"
git fetch --quiet --depth 1 "$PROXMOX_KERNEL_URL" "+refs/tags/${PVE_KERNEL_TAG}:refs/tags/${PVE_KERNEL_TAG}"

# gbp only builds on the branch named in gbp.conf (proxmox/7.3)
git show "${PVE_KERNEL_TAG}:debian/gbp.conf" > /tmp/gbp.conf
BRANCH=$(sed -n 's/^debian-branch *= *//p' /tmp/gbp.conf)
git checkout --quiet --force -B "$BRANCH" "$PVE_KERNEL_TAG"
git clean -qfdx

# 7.3.5 -> v7.3.5, 7.3~rc4 -> v7.3-rc4 (the upstream-tag pattern in gbp.conf)
UPSTREAM_VERSION=$(dpkg-parsechangelog -SVersion | sed 's/-[^-]*$//')
UPSTREAM_TAG="v${UPSTREAM_VERSION//\~/-}"
echo "==> Fetching upstream tag ${UPSTREAM_TAG}"
git fetch --quiet --depth 1 "$PROXMOX_KERNEL_URL" "+refs/tags/${UPSTREAM_TAG}:refs/tags/${UPSTREAM_TAG}"

KERNEL_MAJMIN=$(echo "$UPSTREAM_VERSION" | grep -oE '^[0-9]+\.[0-9]+')
echo "    Kernel version: $(dpkg-parsechangelog -SVersion), series ${KERNEL_MAJMIN}"

# Add the t2linux patches to the end of Proxmox's series. Rebased versions in
# patches/t2-overrides/<major.minor>/ replace the t2linux patch of the same name;
# patches listed in its skip file are already in this kernel and are left out.
echo "==> Adding t2linux patches to debian/patches"
OVERRIDE_DIR="$REPO_ROOT/patches/t2-overrides/${KERNEL_MAJMIN}"
mkdir -p debian/patches/t2
for p in ../linux-t2-patches/*.patch; do
  name=$(basename "$p")
  if grep -qxF "$name" "$OVERRIDE_DIR/skip" 2>/dev/null; then
    echo "    Skipping (already in this kernel): $name"
    continue
  fi
  if [ -e "$OVERRIDE_DIR/$name" ]; then
    echo "    Using rebased override: $name"
    p="$OVERRIDE_DIR/$name"
  fi
  cp "$p" debian/patches/t2/
  echo "t2/$name" >> debian/patches/series
done

echo "==> Applying T2-proxmox-kernel.patch (package names and config)"
git apply "$REPO_ROOT/patches/T2-proxmox-kernel.patch"

# The ABI and firmware checks compare against Proxmox's last release; our T2 drivers add
# symbols and firmware references, so without the baselines both checks are skipped.
# T2 firmware comes from macOS anyway, not from pve-firmware.
rm -f debian/abi/abi-prev-* debian/fwlist/fwlist-previous-*

# debian/control is generated from control.in and must be committed: gbp exports HEAD
debian/rules debian/control
git add -A
git commit --quiet -m "Add T2 support"

echo "==> Installing build dependencies"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git-buildpackage
DEBIAN_FRONTEND=noninteractive apt-get build-dep -y -qq ./

if [ "$COMPILER" = "clang" ]; then
  echo "==> clang builds aren't supported for ${KERNEL_MAJMIN} yet, building with gcc"
fi
echo "==> Building kernel packages (this may take 30-60 minutes)"
make deb

echo "==> Build complete!"
ls -lh build-output/*.deb
if [ -d "$REPO_ROOT" ]; then
  echo "==> Copying packages to $REPO_ROOT"
  cp build-output/*.deb "$REPO_ROOT/"
fi
