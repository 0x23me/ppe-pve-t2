#!/bin/bash
set -e

# Find the correct t2linux commit for a given kernel version
# Usage: ./find-t2-commit.sh 6.17

PVE_MAJOR_MINOR="$1"

if [ -z "$PVE_MAJOR_MINOR" ]; then
  echo "Usage: $0 <kernel_version>" >&2
  echo "Example: $0 6.17" >&2
  exit 1
fi

echo "==> Finding t2linux commit for kernel ${PVE_MAJOR_MINOR}" >&2

# Calculate next version (6.17 → 6.18)
MAJOR=$(echo "$PVE_MAJOR_MINOR" | cut -d. -f1)
MINOR=$(echo "$PVE_MAJOR_MINOR" | cut -d. -f2)
NEXT_VERSION="${MAJOR}.$((MINOR + 1))"

echo "    Looking for version bump to ${NEXT_VERSION}" >&2

# Clone t2linux patches repository
WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

cd "$WORK_DIR"
git clone --quiet https://github.com/t2linux/linux-t2-patches.git
cd linux-t2-patches

# Find commit that bumped to next version (commit message = "6.18")
BUMP_COMMIT=$(git log --oneline --all --grep="^${NEXT_VERSION}$" --format="%H" | tail -1)

if [ -n "$BUMP_COMMIT" ]; then
  # Use the commit BEFORE the version bump
  T2_COMMIT=$(git rev-parse "${BUMP_COMMIT}^")
  T2_KVER=$(git show "${T2_COMMIT}:version" 2>/dev/null || echo "unknown")
  echo "    Found bump to ${NEXT_VERSION} at ${BUMP_COMMIT}" >&2
  echo "    Using parent commit: ${T2_COMMIT}" >&2
  echo "    t2linux KVER: ${T2_KVER}" >&2
else
  # No bump found = we're on latest version, use HEAD
  T2_COMMIT=$(git rev-parse HEAD)
  T2_KVER=$(cat version 2>/dev/null || echo "unknown")
  echo "    No ${NEXT_VERSION} bump found, using HEAD: ${T2_COMMIT}" >&2
  echo "    t2linux KVER: ${T2_KVER}" >&2
fi

# Output JSON for easy parsing
echo "{\"commit\": \"${T2_COMMIT}\", \"kver\": \"${T2_KVER}\"}"
