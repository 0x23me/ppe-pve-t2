#!/bin/bash
set -e

# Publish packages to APT repository using aptly
# This script is run by the publish.yml workflow

REPO_NAME="ppe-pve-t2"
DIST="trixie"
COMPONENT="main"
DEB_DIR="${1:-.}"  # Default to current directory
PREFIX="${2:-.}"   # aptly publish prefix: "." for the stable repo, "beta" for branch builds

echo "==> Publishing packages to APT repository"
echo "    Repository: ${REPO_NAME}"
echo "    Distribution: ${DIST}"
echo "    Component: ${COMPONENT}"
echo "    Package directory: ${DEB_DIR}"
echo "    Prefix: ${PREFIX}"

# Import GPG key if GPG_PRIVATE_KEY environment variable is set
if [ -n "$GPG_PRIVATE_KEY" ]; then
  echo "==> Importing GPG key from environment"
  echo "$GPG_PRIVATE_KEY" | gpg --batch --import
  GPG_KEY_ID=$(echo "$GPG_PRIVATE_KEY" | gpg --batch --show-keys --with-colons | grep '^fpr' | head -1 | cut -d: -f10)
  echo "    GPG Key ID: ${GPG_KEY_ID}"
else
  echo "    Warning: No GPG_PRIVATE_KEY in environment, using existing key"
  GPG_KEY_ID=$(gpg --list-secret-keys --with-colons | grep '^fpr' | head -1 | cut -d: -f10)
fi

# Create aptly repository if it doesn't exist
if ! aptly repo show "$REPO_NAME" >/dev/null 2>&1; then
  echo "==> Creating aptly repository: ${REPO_NAME}"
  aptly repo create -distribution="$DIST" -component="$COMPONENT" "$REPO_NAME"
else
  echo "==> Repository ${REPO_NAME} already exists"
fi

# Add packages to repository
echo "==> Adding packages to repository"
DEB_COUNT=$(find "$DEB_DIR" -name "*.deb" | wc -l)
echo "    Found ${DEB_COUNT} .deb files"

if [ "$DEB_COUNT" -eq 0 ]; then
  echo "    Error: No .deb files found in ${DEB_DIR}" >&2
  exit 1
fi

# Add each package
find "$DEB_DIR" -name "*.deb" | while read -r deb; do
  echo "    Adding: $(basename "$deb")"
  aptly repo add "$REPO_NAME" "$deb" || echo "    (package already exists, skipping)"
done

# Publish repository
echo "==> Publishing repository"
if aptly publish show "$DIST" "$PREFIX" >/dev/null 2>&1; then
  echo "    Updating existing publication"
  aptly publish update -gpg-key="$GPG_KEY_ID" "$DIST" "$PREFIX"
else
  echo "    Creating new publication"
  aptly publish repo -gpg-key="$GPG_KEY_ID" -distribution="$DIST" "$REPO_NAME" "$PREFIX"
fi

# Copy published repository to docs/
echo "==> Copying published repository to docs/"
mkdir -p docs
rm -rf docs/pool docs/dists
cp -r ~/.aptly/public/"$PREFIX"/pool docs/
cp -r ~/.aptly/public/"$PREFIX"/dists docs/

# Export public GPG key
echo "==> Exporting public GPG key"
gpg --armor --export "$GPG_KEY_ID" > docs/KEY.gpg

echo "==> Repository published successfully!"
echo "    Pool: docs/pool/"
echo "    Metadata: docs/dists/"
echo "    Public key: docs/KEY.gpg"
