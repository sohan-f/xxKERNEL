#!/usr/bin/env bash
# Bazel compile body, invoked via nick-fields/retry command wrapper.
# Same output as old Compile Kernel step. Requires: KERNEL_ROOT, KSU_LATEST_COMMIT_DATE
set -o pipefail
{
  echo "Compile attempt: ${ATTEMPT:-1}"
  echo "Start time: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "Current KernelSU latest commit date: ${KSU_LATEST_COMMIT_DATE:-Unknown}"
  set -ex
  cd "$KERNEL_ROOT"

  # Extract defconfig changes into a fragment for Kleaf/Bazel build
  FRAG="common/arch/arm64/configs/ksu.fragment"
  diff "$DEFCONFIG.orig" "$DEFCONFIG" | grep '^>' | sed 's/^> //; s/^[[:space:]]*//' > "$FRAG" || true
  cp "$DEFCONFIG.orig" "$DEFCONFIG"
  echo "=== KSU Fragment Content ==="
  cat "$FRAG"
  echo "========================="

  FRAG_FLAG=""
  if [ -s "$FRAG" ]; then
    FRAG_FLAG="--defconfig_fragment=//common:arch/arm64/configs/ksu.fragment"
  fi

  tools/bazel build \
      --config=fast \
      $FRAG_FLAG \
      --action_env=PATH \
      --action_env='KCFLAGS=-march=armv8.2-a+crypto+fp16+dotprod+rcpc+dcpop -mtune=cortex-a78' \
      //common:kernel_aarch64_autofdo_dist || exit 1

  IMAGE=$(find ./bazel-bin/common -maxdepth 2 -name Image -type f | head -n1)
  if [ -z "$IMAGE" ]; then
    echo "::error::Kernel Image not found under ./bazel-bin/common"
    find ./bazel-bin -maxdepth 3 -type f -name 'Image*' || true
    exit 1
  fi
  strings "$IMAGE" | grep 'Linux version'

  echo "Current KernelSU latest commit date: ${KSU_LATEST_COMMIT_DATE:-Unknown}"
} 2>&1 | tee "$LOG_FILE"

BUILD_STATUS=${PIPESTATUS[0]}
{
  echo "End time: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "Exit code: $BUILD_STATUS"
} >> "$LOG_FILE"
exit "$BUILD_STATUS"
