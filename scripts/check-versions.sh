#!/bin/bash
set -e

# Check if one kernel series ("train", e.g. 7.0 or 7.3) has a new upstream version and output JSON
# Usage: ./check-versions.sh 7.3
# This script is used by the check-upstream.yml workflow, once for each train in versions.json

SERIES="$1"
if [ -z "$SERIES" ]; then
  echo "Usage: $0 <kernel series, e.g. 7.3>" >&2
  exit 1
fi

echo "==> Checking for upstream version updates of ${SERIES}" >&2

# Since 7.3 Proxmox keeps the kernel in proxmox-kernel.git and tags each release
# (proxmox/7.3.5-1); build-kernel.sh builds such a tag with build-proxmox-kernel.sh.
LATEST_PVE_TAG=$(git ls-remote --tags --refs git://git.proxmox.com/git/proxmox-kernel.git \
  "refs/tags/proxmox/${SERIES}.*" | sed 's|.*refs/tags/||' | sort -V | tail -1)

# Older series are on pve-kernel.git master, which Proxmox no longer tags (the only tags
# are old 6.8 ones), and the newest version bump can reference a zfsonlinux commit that
# isn't published yet, so find-pve-commit.sh walks back to the newest one that can be built.
if [ -z "$LATEST_PVE_TAG" ]; then
  PVE_INFO=$(bash "$(dirname "$0")/find-pve-commit.sh")
  PVE_VERSION=$(echo "$PVE_INFO" | jq -r '.version')   # e.g. "7.0.14-26"
  if [ "$(echo "$PVE_VERSION" | cut -d. -f1,2)" != "$SERIES" ]; then
    echo "    ERROR: no ${SERIES} release in proxmox-kernel.git, and pve-kernel.git master is at ${PVE_VERSION}" >&2
    exit 1
  fi
  # build-kernel.sh checks out the matching "bump version to" commit
  LATEST_PVE_TAG="proxmox-kernel-${PVE_VERSION}"
fi
echo "    Latest buildable release: ${LATEST_PVE_TAG}" >&2

# Find appropriate t2linux commit using our script
echo "    Finding t2linux commit for kernel ${SERIES}..." >&2
T2_INFO=$(bash "$(dirname "$0")/find-t2-commit.sh" "$SERIES")
T2_COMMIT=$(echo "$T2_INFO" | jq -r '.commit')
T2_KVER=$(echo "$T2_INFO" | jq -r '.kver')

echo "    t2linux commit: ${T2_COMMIT}" >&2
echo "    t2linux KVER: ${T2_KVER}" >&2

# Read current versions.json if it exists
if [ -f versions.json ]; then
  LAST_PVE_TAG=$(jq -r --arg s "$SERIES" '.trains[$s].last_build.pve_kernel_tag // ""' versions.json)
  LAST_T2_COMMIT=$(jq -r --arg s "$SERIES" '.trains[$s].last_build.t2linux_commit // ""' versions.json)
  PINNED_T2_COMMIT=$(jq -r --arg s "$SERIES" '.trains[$s].pinned_t2linux_commit // ""' versions.json)

  # If there's a pinned commit, use it instead of auto-detected
  if [ -n "$PINNED_T2_COMMIT" ] && [ "$PINNED_T2_COMMIT" != "null" ]; then
    echo "    Using pinned t2linux commit: ${PINNED_T2_COMMIT}" >&2
    T2_COMMIT="$PINNED_T2_COMMIT"
  fi
else
  LAST_PVE_TAG=""
  LAST_T2_COMMIT=""
fi

echo "    Last built pve-kernel tag: ${LAST_PVE_TAG:-none}" >&2
echo "    Last built t2linux commit: ${LAST_T2_COMMIT:-none}" >&2

# Determine if we need to build
NEEDS_BUILD="false"
if [ "$LATEST_PVE_TAG" != "$LAST_PVE_TAG" ]; then
  echo "    ✓ New pve-kernel tag detected" >&2
  NEEDS_BUILD="true"
elif [ "$T2_COMMIT" != "$LAST_T2_COMMIT" ]; then
  echo "    ✓ New t2linux commit detected" >&2
  NEEDS_BUILD="true"
else
  echo "    ✗ No new versions detected" >&2
fi

# Output JSON for workflow
jq -n \
  --arg series "$SERIES" \
  --arg needs_build "$NEEDS_BUILD" \
  --arg pve_tag "$LATEST_PVE_TAG" \
  --arg t2_commit "$T2_COMMIT" \
  --arg t2_kver "$T2_KVER" \
  '{
    series: $series,
    needs_build: $needs_build,
    pve_kernel_tag: $pve_tag,
    t2linux_commit: $t2_commit,
    t2linux_kver: $t2_kver
  }'
