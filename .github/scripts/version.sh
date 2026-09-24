#!/usr/bin/env bash
set -euo pipefail
# Version stamp + build time + verify. Same output as old version action.
# Inputs via env: VERSION, INPUT_TIME
# Requires: KERNEL_ROOT

: "${KERNEL_ROOT:?}"
VERSION_INPUT="$(echo "${VERSION:-}" | tr -d '[:space:]')"
INPUT_TIME="${INPUT_TIME:-}"

cd "$KERNEL_ROOT"
sed -i '/^[[:space:]]*"protected_exports_list"[[:space:]]*:[[:space:]]*"android\/abi_gki_protected_exports_aarch64",$/d' ./common/BUILD.bazel
sed -i '/kmi_symbol_list_strict_mode/d' ./common/BUILD.bazel
rm -rf ./common/android/abi_gki_protected_exports_*
sed -i '/stable_scmversion_cmd/s/-maybe-dirty//g' ./build/kernel/kleaf/impl/stamp.bzl

if [ -n "$VERSION_INPUT" ]; then
  CLEAN_VERSION=$(echo "$VERSION_INPUT" | sed -E 's/^[0-9]+\.[0-9]+\.[0-9]+//')
  perl -i -0777 -pe \
    's/(.*)echo "\$\{KERNELVERSION\}\$\{file_localversion\}\$\{config_localversion\}\$\{LOCALVERSION\}\$\{scm_version\}"/$1echo "\$\{KERNELVERSION\}'"${CLEAN_VERSION}"'"/s' \
    ./common/scripts/setlocalversion 2>/dev/null || true
  sed -i "\$s|echo \"\$res\"|echo \"${CLEAN_VERSION}\"|" \
    ./common/scripts/setlocalversion 2>/dev/null || true
  sed -i '/^CONFIG_LOCALVERSION=/ s/="[^"]*"/="'"$CLEAN_VERSION"'"/' \
    ./common/arch/arm64/configs/gki_defconfig
else
  cd ./common
  BID="ab10000069"
  GHASH=$(git rev-parse --verify HEAD | cut -c1-13)
  KMI_TAG="android15-8"
  SUFFIX="-${KMI_TAG}-g${GHASH}-${BID}"
  perl -i -0777 -pe \
    's/(.*)echo "\$\{KERNELVERSION\}\$\{file_localversion\}\$\{config_localversion\}\$\{LOCALVERSION\}\$\{scm_version\}"/$1echo "\$\{KERNELVERSION\}'"${SUFFIX}"'"/s' \
    ./scripts/setlocalversion
  cd ..
fi

echo "Expected kernel version:"
make -C common -s kernelversion

if [[ -n "$INPUT_TIME" && "$INPUT_TIME" != "N" && "$INPUT_TIME" != "n" ]]; then
  TIME_REGEX='^(Mon|Tue|Wed|Thu|Fri|Sat|Sun) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) (0[1-9]|[12][0-9]|3[01]) ([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9] UTC [0-9]{4}$'
  if [[ ! "$INPUT_TIME" =~ $TIME_REGEX ]]; then
    echo "::warning title=Build time format error::Custom build time must be formatted like 'Sun Dec 01 08:10:00 UTC 2024'. Please remove extra prefixes and use a two-digit day."
    exit 1
  fi
  NORMALIZED_TIME="$(LC_ALL=C TZ=UTC date -u -d "$INPUT_TIME" +'%a %b %d %T UTC %Y' 2>/dev/null || true)"
  if [[ "$NORMALIZED_TIME" != "$INPUT_TIME" ]]; then
    echo "::warning title=Invalid build time::Custom build time cannot be parsed as valid UTC time, or the day of the week does not match the date."
    exit 1
  fi
  DATESTR="$INPUT_TIME"
else
  DATESTR="$(TZ='UTC' date +'%a %b %d %T %Z %Y')"
fi

echo "KBUILD_BUILD_TIMESTAMP=$DATESTR" >> "$GITHUB_ENV"
echo "KBUILD_BUILD_VERSION=1" >> "$GITHUB_ENV"
echo "KBUILD_BUILD_USER=sohan" >> "$GITHUB_ENV"
echo "KBUILD_BUILD_HOST=cuscoi" >> "$GITHUB_ENV"

f="$KERNEL_ROOT/common/scripts/mkcompile_h"
if [ -f "$f" ]; then
  echo "Applying 6.x mkcompile_h patch: $f"
  if grep -q 'UTS_VERSION=' "$f"; then
    perl -pi -e "s{UTS_VERSION=\"\\\$\\\(.*?\\\)\"}{UTS_VERSION=\"#1 SMP PREEMPT $DATESTR\"}" "$f"
  else
    perl -0777 -pi -e "s{cat <<EOF}{cat <<EOF\n#undef UTS_VERSION\n#define UTS_VERSION \"#1 SMP PREEMPT $DATESTR\" } unless /UTS_VERSION/" "$f"
  fi
fi

cd "$KERNEL_ROOT/common"
echo "Git commit: $(git rev-parse HEAD)"
echo "Git describe: $(git describe --always --dirty --long)"
echo "Kernel version: $(make -s kernelversion)"
grep -E '^(VERSION|PATCHLEVEL|SUBLEVEL|EXTRAVERSION)' Makefile
