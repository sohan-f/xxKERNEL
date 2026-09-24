#!/usr/bin/env bash
set -euo pipefail
# KernelSU + hooks + base Kconfig + flavor overlay. Same output as before for FLAVOR=perf.
# Requires: KERNEL_ROOT, DEFCONFIG, GITHUB_WORKSPACE
# Inputs via env: FLAVOR (perf|battery, default perf)

: "${KERNEL_ROOT:?}"
: "${DEFCONFIG:?}"

FLAVOR="${FLAVOR:-perf}"
case "$FLAVOR" in
  perf|battery) ;;
  *) echo "::error::Unknown FLAVOR=$FLAVOR (want perf|battery)"; exit 1 ;;
esac

cd "$KERNEL_ROOT"

echo "Adding backslashxx KernelSU..."
rm -rf KernelSU
curl -LSs "https://raw.githubusercontent.com/backslashxx/KernelSU/refs/heads/master/kernel/setup.sh" | bash -s master

cd common
patch -p1 --forward < "${GITHUB_WORKSPACE}/backslashxx_hooks/manual_hooks.patch"
patch -p1 --forward < "${GITHUB_WORKSPACE}/backslashxx_hooks/thermal_patch.patch"
cd ..

cd KernelSU
KSU_GIT_VERSION=$(git rev-list --count HEAD)
KSU_VERSION=$((20000 + KSU_GIT_VERSION))
echo "KSU_VERSION=$KSU_VERSION" >> "$GITHUB_ENV"

if [ -f "kernel/Kbuild" ]; then
  sed -i "s/DKSU_VERSION=16/DKSU_VERSION=${KSU_VERSION}/" kernel/Kbuild
fi

patch -p1 --forward < "${GITHUB_WORKSPACE}/backslashxx_hooks/cpu_optimization.patch"
cd ..

if [ -d "KernelSU/.git" ]; then
  KSU_LATEST_COMMIT_DATE=$(git -C KernelSU log -1 --date=format:'%Y-%m-%d %H:%M:%S %z' --format='%cd')
  echo "KSU_LATEST_COMMIT_DATE=$KSU_LATEST_COMMIT_DATE" >> "$GITHUB_ENV"
else
  echo "KSU_LATEST_COMMIT_DATE=Unknown" >> "$GITHUB_ENV"
fi

echo "Applying kernel configurations (base + $FLAVOR)..."
# shellcheck source=kernel-config.sh
source "${GITHUB_WORKSPACE}/.github/scripts/kernel-config.sh"
while IFS= read -r line || [ -n "$line" ]; do
  apply_line "$line" "$DEFCONFIG"
done < "${GITHUB_WORKSPACE}/.github/configs/ksu-base.fragment"
while IFS= read -r line || [ -n "$line" ]; do
  apply_line "$line" "$DEFCONFIG"
done < "${GITHUB_WORKSPACE}/.github/configs/${FLAVOR}.fragment"

sed -i 's/check_defconfig//' ./common/build.config.gki
