#!/bin/bash
set -e

# Check if there are new versions upstream and output JSON result
# This script is used by the check-upstream.yml workflow

echo "==> Checking for upstream version updates" >&2

# Get latest pve-kernel tag
echo "    Fetching latest pve-kernel tag..." >&2
LATEST_PVE_TAG=$(git ls-remote --tags --sort=-v:refname git://git.proxmox.com/git/pve-kernel.git | \
  grep -v '\^{}' | \
  head -1 | \
  awk '{print $2}' | \
  sed 's|refs/tags/||')

echo "    Latest pve-kernel tag: ${LATEST_PVE_TAG}" >&2

# Extract kernel major.minor version from tag (e.g., "pve-kernel-6.17.4-2" → "6.17")
KERNEL_MAJMIN=$(echo "$LATEST_PVE_TAG" | sed 's/pve-kernel-//' | cut -d. -f1,2)
echo "    Kernel major.minor: ${KERNEL_MAJMIN}" >&2

# Find appropriate t2linux commit using our script
echo "    Finding t2linux commit for kernel ${KERNEL_MAJMIN}..." >&2
T2_INFO=$(bash "$(dirname "$0")/find-t2-commit.sh" "$KERNEL_MAJMIN")
T2_COMMIT=$(echo "$T2_INFO" | jq -r '.commit')
T2_KVER=$(echo "$T2_INFO" | jq -r '.kver')

echo "    t2linux commit: ${T2_COMMIT}" >&2
echo "    t2linux KVER: ${T2_KVER}" >&2

# Read current versions.json if it exists
if [ -f versions.json ]; then
  LAST_PVE_TAG=$(jq -r '.last_build.pve_kernel_tag // ""' versions.json)
  LAST_T2_COMMIT=$(jq -r '.last_build.t2linux_commit // ""' versions.json)
  PINNED_T2_COMMIT=$(jq -r '.pinned_t2linux_commit // ""' versions.json)

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
  --arg needs_build "$NEEDS_BUILD" \
  --arg pve_tag "$LATEST_PVE_TAG" \
  --arg t2_commit "$T2_COMMIT" \
  --arg t2_kver "$T2_KVER" \
  '{
    needs_build: $needs_build,
    pve_kernel_tag: $pve_tag,
    t2linux_commit: $t2_commit,
    t2linux_kver: $t2_kver
  }'
