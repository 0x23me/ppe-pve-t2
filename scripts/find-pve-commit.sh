#!/bin/bash
set -e

# Find the newest buildable pve-kernel release on master.
# Usage: ./find-pve-commit.sh [max_releases_to_try]
#
# Proxmox sometimes bumps the kernel version on master before the matching
# zfsonlinux submodule commit is published ("upload-pack: not our ref"), which
# makes `git submodule update` fail. Walk the "bump version to X" commits from
# newest to oldest and return the first whose zfsonlinux commit is fetchable.
#
# Output (stdout): {"commit": "<sha>", "version": "7.0.14-26"}

MAX_TRIES="${1:-5}"
PVE_KERNEL_URL="git://git.proxmox.com/git/pve-kernel.git"
ZFS_URL="git://git.proxmox.com/git/zfsonlinux.git"

echo "==> Finding newest buildable pve-kernel release" >&2

WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

# Only commit/tree metadata is needed, not file contents
git clone --quiet --bare --filter=blob:none --single-branch --branch master \
  "$PVE_KERNEL_URL" "$WORK_DIR/pve-kernel.git"
git init --quiet "$WORK_DIR/zfs-probe"

tries=0
for c in $(git -C "$WORK_DIR/pve-kernel.git" log --format=%H --grep='^bump version to ' master); do
  tries=$((tries + 1))
  [ "$tries" -gt "$MAX_TRIES" ] && break

  version=$(git -C "$WORK_DIR/pve-kernel.git" log -1 --format=%s "$c" | sed 's/^bump version to //')
  zfs_sha=$(git -C "$WORK_DIR/pve-kernel.git" ls-tree "$c" submodules/zfsonlinux | awk '{print $3}')

  if git -C "$WORK_DIR/zfs-probe" fetch --quiet --depth 1 "$ZFS_URL" "$zfs_sha" 2>/dev/null; then
    echo "    ${version}: zfsonlinux ${zfs_sha:0:12} available -> using ${c:0:12}" >&2
    echo "{\"commit\": \"${c}\", \"version\": \"${version}\"}"
    exit 0
  fi
  echo "    ${version}: zfsonlinux ${zfs_sha:0:12} not published yet, trying older release" >&2
done

echo "    ERROR: no buildable release in the last ${MAX_TRIES} version bumps" >&2
exit 1
