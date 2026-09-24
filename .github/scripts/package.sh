#!/usr/bin/env bash
set -euo pipefail
# Copy built Image into AnyKernel3. Requires: KERNEL_ROOT, ANYKERNEL3
: "${KERNEL_ROOT:?}"
: "${ANYKERNEL3:?}"

IMAGE=$(find "$KERNEL_ROOT/bazel-bin/common" -maxdepth 2 -name Image -type f | head -n1)
if [ -z "$IMAGE" ]; then
  echo "::error::Kernel Image not found under $KERNEL_ROOT/bazel-bin/common"
  find "$KERNEL_ROOT/bazel-bin" -maxdepth 3 -type f -name 'Image*' || true
  exit 1
fi
echo "Using Image: $IMAGE"
cp "$IMAGE" "$ANYKERNEL3/Image"
