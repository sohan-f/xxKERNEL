#!/usr/bin/env bash
set -euo pipefail
# Stock config.gz spoofing. DISABLED (kept for future re-enable after
# config/stock_defconfig is updated to match LTS HEAD).
# Requires: KERNEL_ROOT, GITHUB_WORKSPACE

: "${KERNEL_ROOT:?}"

STOCK_SRC="$GITHUB_WORKSPACE/config/stock_defconfig"
STOCK_DST="$KERNEL_ROOT/common/arch/arm64/configs/stock_defconfig"

if [ ! -f "$STOCK_SRC" ]; then
  echo "$STOCK_SRC not detected, skipping Stock Config spoofing."
  exit 0
fi

mkdir -p "$(dirname "$STOCK_DST")"
if ! cp "$STOCK_SRC" "$STOCK_DST"; then
  echo "::error::Failed to copy stock_defconfig: $STOCK_SRC -> $STOCK_DST"
  exit 1
fi
echo "Copied stock_defconfig -> $STOCK_DST"

NEW_RULE='$(obj)/config_data: arch/arm64/configs/stock_defconfig FORCE'
OLD_RULE='$(obj)/config_data: $(KCONFIG_CONFIG) FORCE'
TARGET_MAKEFILE="$KERNEL_ROOT/common/kernel/Makefile"

if [ ! -f "$TARGET_MAKEFILE" ]; then
  echo "::error::$TARGET_MAKEFILE not found"
  exit 1
fi

if grep -qF "$NEW_RULE" "$TARGET_MAKEFILE"; then
  echo "config_data rule is already stock_defconfig, skipping."
elif grep -qF "$OLD_RULE" "$TARGET_MAKEFILE"; then
  sed -i 's|$(obj)/config_data: $(KCONFIG_CONFIG) FORCE|$(obj)/config_data: arch/arm64/configs/stock_defconfig FORCE|' "$TARGET_MAKEFILE"
  echo "Replaced config_data rule: $TARGET_MAKEFILE"
else
  echo "::error::Rule not found in $TARGET_MAKEFILE: $OLD_RULE"
  exit 1
fi
