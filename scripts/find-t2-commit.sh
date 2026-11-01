#!/bin/bash
set -e

# Find the correct t2linux commit for a given kernel version
# Usage: ./find-t2-commit.sh 6.17
#
# t2linux records the kernel it targets in its `version` file (e.g. "KVER=7.0.4",
# "KVER=7.2-rc6"). Commit messages for bumps are free-form ("linux 7",
# "7.1 + new SMC patches"), so we don't rely on them. Instead we walk the
# history of `version` from oldest to newest, find the first commit that targets
# a kernel series newer than ours, and use its parent: the last state of the
# patches for our series.

PVE_MAJOR_MINOR="$1"

if [ -z "$PVE_MAJOR_MINOR" ]; then
  echo "Usage: $0 <kernel_version>" >&2
  echo "Example: $0 6.17" >&2
  exit 1
fi

echo "==> Finding t2linux commit for kernel ${PVE_MAJOR_MINOR}" >&2

# Clone t2linux patches repository
WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

cd "$WORK_DIR"
git clone --quiet https://github.com/t2linux/linux-t2-patches.git
cd linux-t2-patches

# "KVER=7.2-rc6" / "KVER=7.0.4" → "7.2" / "7.0"
kver_majmin() {
  sed -n 's/^KVER=//p' | head -1 | grep -oE '^[0-9]+\.[0-9]+'
}

# Is $1 a newer major.minor than $2? (version sort, so 6.19 < 7.0 < 7.10)
newer_than() {
  [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]
}

BUMP_COMMIT=""
BUMP_SERIES=""
for c in $(git log --reverse --format=%H -- version); do
  series=$(git show "${c}:version" 2>/dev/null | kver_majmin || true)
  [ -z "$series" ] && continue
  if newer_than "$series" "$PVE_MAJOR_MINOR"; then
    BUMP_COMMIT="$c"
    BUMP_SERIES="$series"
    break
  fi
done

if [ -n "$BUMP_COMMIT" ]; then
  # Use the commit BEFORE the first bump past our series
  T2_COMMIT=$(git rev-parse "${BUMP_COMMIT}^")
  T2_KVER=$(git show "${T2_COMMIT}:version" 2>/dev/null || echo "unknown")
  echo "    First bump past ${PVE_MAJOR_MINOR}: ${BUMP_SERIES} at ${BUMP_COMMIT}" >&2
  echo "    Using parent commit: ${T2_COMMIT}" >&2
else
  # Nothing newer than our series yet = t2linux HEAD targets it
  T2_COMMIT=$(git rev-parse HEAD)
  T2_KVER=$(cat version 2>/dev/null || echo "unknown")
  echo "    No t2linux series newer than ${PVE_MAJOR_MINOR}, using HEAD: ${T2_COMMIT}" >&2
fi

T2_SERIES=$(echo "$T2_KVER" | kver_majmin || true)
echo "    t2linux KVER: ${T2_KVER}" >&2
if [ "$T2_SERIES" != "$PVE_MAJOR_MINOR" ]; then
  echo "    WARNING: t2linux patches target ${T2_SERIES:-unknown}, not ${PVE_MAJOR_MINOR}" >&2
fi

# Output JSON for easy parsing
echo "{\"commit\": \"${T2_COMMIT}\", \"kver\": \"${T2_KVER}\"}"
