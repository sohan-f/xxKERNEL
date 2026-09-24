#!/usr/bin/env bash
set -euo pipefail
# Setup runner env, deps, clones. Same output as old setup action.
# Requires: GITHUB_WORKSPACE, GITHUB_ENV, GITHUB_PATH
# Inputs via env: ANDROID_VERSION, KERNEL_VERSION

: "${ANDROID_VERSION:?ANDROID_VERSION required}"
: "${KERNEL_VERSION:?KERNEL_VERSION required}"

CONFIG="${ANDROID_VERSION}-${KERNEL_VERSION}-lts"
KERNEL_ROOT="$GITHUB_WORKSPACE/$CONFIG"
mkdir -p "$KERNEL_ROOT"

cat >> "$GITHUB_ENV" << EOF
CONFIG=$CONFIG
KERNEL_ROOT=$KERNEL_ROOT
DEFCONFIG=$KERNEL_ROOT/common/arch/arm64/configs/gki_defconfig
KERNEL_PATCHES=$GITHUB_WORKSPACE/kernel_patches
ANYKERNEL3=$GITHUB_WORKSPACE/AnyKernel3
BAZEL_DISK_CACHE=$HOME/.cache/bazel-disk
EOF
mkdir -p "$BAZEL_DISK_CACHE"

mkdir -p "$GITHUB_WORKSPACE/git-repo"
curl -L https://storage.googleapis.com/git-repo-downloads/repo -o "$GITHUB_WORKSPACE/git-repo/repo"
chmod 0755 "$GITHUB_WORKSPACE/git-repo/repo"
echo "$GITHUB_WORKSPACE/git-repo" >> "$GITHUB_PATH"
echo "REPO=$GITHUB_WORKSPACE/git-repo/repo" >> "$GITHUB_ENV"

sudo apt-get update
sudo apt-get install -y python3 git curl build-essential libssl-dev bison flex libelf-dev dwarves

KSU_HASH=$(git ls-remote https://github.com/backslashxx/KernelSU refs/heads/master | cut -f1 | head -c12)
echo "KSU_HASH=${KSU_HASH}" >> "$GITHUB_ENV"
echo "KernelSU HEAD: ${KSU_HASH}"

git config --global user.name "builder"
git config --global user.email "builder@example.com"

echo "Cloning AnyKernel3..."
git clone https://github.com/sohan-f/AnyKernel3.git -b "cuscoi"
echo "Preparing patch resources..."
git clone https://github.com/WildKernels/kernel_patches.git

rm -rf AnyKernel3/.git
rm -rf kernel_patches/.git
