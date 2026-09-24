#!/usr/bin/env bash
set -euo pipefail
# Backup baseline defconfig and extract actual SUBLEVEL. Run after cache save.
# Requires: KERNEL_ROOT, DEFCONFIG

: "${KERNEL_ROOT:?}"
: "${DEFCONFIG:?}"

cp "$DEFCONFIG" "$DEFCONFIG.orig"

ACTUAL_SUBLEVEL="lts"
if [[ -f "$KERNEL_ROOT/common/Makefile" ]]; then
  EXTRACTED=$(grep '^SUBLEVEL = ' "$KERNEL_ROOT/common/Makefile" | awk '{print $3}')
  [[ -n "$EXTRACTED" ]] && ACTUAL_SUBLEVEL="$EXTRACTED"
fi
echo "ACTUAL_SUBLEVEL=$ACTUAL_SUBLEVEL" >> "$GITHUB_ENV"
echo "sublevel=$ACTUAL_SUBLEVEL" >> "$GITHUB_OUTPUT"
echo "Actual sublevel: $ACTUAL_SUBLEVEL"
