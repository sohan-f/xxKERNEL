#!/usr/bin/env bash
set -euo pipefail
# Resolve LTS manifest HEAD. Sets MANIFEST_HASH in GITHUB_ENV and step output.
# Inputs via env: ANDROID_VERSION, KERNEL_VERSION, FLAVOR

: "${ANDROID_VERSION:?}"
: "${KERNEL_VERSION:?}"

FLAVOR="${FLAVOR:-perf}"

BRANCH="common-${ANDROID_VERSION}-${KERNEL_VERSION}-lts"
MANIFEST_HASH=$(git ls-remote https://android.googlesource.com/kernel/manifest \
  "refs/heads/${BRANCH}" | cut -f1 | head -c12)
if [[ -z "$MANIFEST_HASH" ]]; then
  echo "::error::Empty manifest hash for branch ${BRANCH} (renamed or network failure)"
  exit 1
fi
echo "MANIFEST_HASH=${MANIFEST_HASH}" >> "$GITHUB_ENV"
echo "hash=${MANIFEST_HASH}" >> "$GITHUB_OUTPUT"
echo "BAZEL_CACHE_KEY=bazel-disk-${ANDROID_VERSION}-${KERNEL_VERSION}-lts-${FLAVOR}-${MANIFEST_HASH}" >> "$GITHUB_ENV"
echo "Manifest HEAD: ${MANIFEST_HASH} (${BRANCH})"
