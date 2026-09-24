#!/usr/bin/env bash
set -euo pipefail
# Repo init/sync LTS source. Run after cache restore miss.
# Inputs via env: ANDROID_VERSION, KERNEL_VERSION, REPO, KERNEL_ROOT

: "${ANDROID_VERSION:?}"
: "${KERNEL_VERSION:?}"
: "${REPO:?}"
: "${KERNEL_ROOT:?}"

cd "$KERNEL_ROOT"

FORMATTED_BRANCH="${ANDROID_VERSION}-${KERNEL_VERSION}-lts"
echo "Initializing repo, branch: common-${FORMATTED_BRANCH}"

"$REPO" init \
  --depth=1 \
  -u https://android.googlesource.com/kernel/manifest \
  -b "common-${FORMATTED_BRANCH}" \
  --repo-rev=v2.16

"$REPO" sync \
  -c \
  -j"$(nproc --all)" \
  --no-tags \
  --fail-fast

echo "Kernel revision:"
git -C "$KERNEL_ROOT/common" log -1 --oneline
echo "Kernel branch:"
git -C "$KERNEL_ROOT/common" branch --show-current
