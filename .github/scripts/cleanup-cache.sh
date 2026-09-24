#!/usr/bin/env bash
set -euo pipefail
# Delete stale LTS source caches, keep current MANIFEST_HASH.
# Inputs via env: ANDROID_VERSION, KERNEL_VERSION, MANIFEST_HASH

: "${ANDROID_VERSION:?}"
: "${KERNEL_VERSION:?}"
: "${MANIFEST_HASH:?}"

PREFIX="kernel-source-${ANDROID_VERSION}-${KERNEL_VERSION}-lts-"
CURRENT="${PREFIX}${MANIFEST_HASH}"
echo "Checking for stale kernel source caches with prefix: $PREFIX"
gh cache list --repo "${GITHUB_REPOSITORY:?}" --key "$PREFIX" --limit 100 --json key -q '.[].key' | \
while read -r k; do
  if [ "$k" != "$CURRENT" ]; then
    echo "Deleting stale kernel source cache: $k"
    gh cache delete "$k" --repo "$GITHUB_REPOSITORY" || true
  fi
done
