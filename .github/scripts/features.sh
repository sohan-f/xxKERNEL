#!/usr/bin/env bash
set -euo pipefail
# All optional features in one entry point. Same output as old features action.
# Inputs via env: ENABLE_NOMOUNT, DROIDSPACES, DROIDSPACES_NTSYNC,
#   ANDROID_VERSION, KERNEL_VERSION, USE_BBG, USE_NETWORKING, USE_PERF
# Requires: KERNEL_ROOT, DEFCONFIG, KERNEL_PATCHES, GITHUB_WORKSPACE

: "${KERNEL_ROOT:?}"
: "${DEFCONFIG:?}"

ENABLE_NOMOUNT="${ENABLE_NOMOUNT:-disabled}"
DROIDSPACES="${DROIDSPACES:-off}"
DROIDSPACES_NTSYNC="${DROIDSPACES_NTSYNC:-false}"
USE_BBG="${USE_BBG:-true}"
USE_NETWORKING="${USE_NETWORKING:-false}"
USE_PERF="${USE_PERF:-true}"

# shellcheck source=kernel-config.sh
source "${GITHUB_WORKSPACE}/.github/scripts/kernel-config.sh"
apply_conf() {
  local conf="$1"
  while IFS= read -r line || [ -n "$line" ]; do
    apply_line "$line" "$DEFCONFIG"
  done < "$conf"
}

if [[ "$ENABLE_NOMOUNT" != "disabled" ]]; then
  echo "Integrating NoMount ($ENABLE_NOMOUNT)..."
  cd "$KERNEL_ROOT/common"
  curl -LSs "https://raw.githubusercontent.com/maxsteeel/nomount/refs/heads/${ENABLE_NOMOUNT}/kernel/setup.sh" | bash -s "$ENABLE_NOMOUNT"
  ( cd "$KERNEL_ROOT/common" && apply_line "CONFIG_NOMOUNT=y" "$DEFCONFIG" )
  echo "NoMount integration completed successfully."
fi

if [[ "$DROIDSPACES" != "off" ]]; then
  echo "Integrating Droidspaces..."
  cd "$KERNEL_ROOT/common"
  PATCH_FILE=/tmp/droidspaces.patch
  curl -LSs "https://raw.githubusercontent.com/ravindu644/Droidspaces-OSS/refs/heads/main/Documentation/resources/kernel-patches/GKI/below-kernel-6.12/001.GKI-below-6.12-fix_sysvipc_kabi_6_7_8.patch" -o "$PATCH_FILE"
  if ! patch -p1 --forward < "$PATCH_FILE"; then
    echo "::warning::Failed to apply SYSVIPC kABI patch; it may already be applied or context mismatched"
  fi
  ( cd "$KERNEL_ROOT/common" && apply_conf "${GITHUB_WORKSPACE}/.github/configs/droidspaces.fragment" )
  rm -f "$PATCH_FILE"
  echo "Droidspaces integration complete"

  echo "Enabling x86_64 emulation (binfmt) configs..."
  ( cd "$KERNEL_ROOT" && apply_conf "${GITHUB_WORKSPACE}/.github/configs/binfmt.fragment" )
fi

if [[ "$DROIDSPACES" != "off" && "$DROIDSPACES_NTSYNC" == "true" ]]; then
  echo "Injecting NTSync kernel patches..."
  NTSYNC_PATCH="ntsync_compat_${ANDROID_VERSION}-${KERNEL_VERSION}"
  NTSYNC_URL="https://raw.githubusercontent.com/Goldzxcbug/Droidspaces_Kernel_patch/refs/heads/main/NTsync"
  cd "$KERNEL_ROOT/common"
  wget -q "$NTSYNC_URL/ntsync_base.patch"
  wget -q "$NTSYNC_URL/${NTSYNC_PATCH}.patch"
  patch -p1 < "ntsync_base.patch"
  patch -p1 < "${NTSYNC_PATCH}.patch"
  echo "Enabling CONFIG_NTSYNC..."
  apply_line "CONFIG_NTSYNC=y" "$DEFCONFIG"
  echo "NTSync patch and configuration injection complete."
fi

if [[ "$USE_BBG" == "true" ]]; then
  echo "Applying BBG..."
  cd "$KERNEL_ROOT"
  wget -O- https://github.com/vc-teahouse/Baseband-guard/raw/main/setup.sh | bash
  apply_line "CONFIG_BBG=y" "$DEFCONFIG"
  sed -i '/^config LSM$/,/^help$/{ /^[[:space:]]*default/ { /baseband_guard/! s/selinux/selinux,baseband_guard/ } }' common/security/Kconfig
fi

if [[ "$USE_NETWORKING" == "true" ]]; then
  echo "Applying bbrv3 patches"
  cd "$KERNEL_ROOT/common"
  patch -p1 --forward < "$KERNEL_PATCHES/common/bbrv3/0001-net-tcp-backport-BBRv3-to-android15-6.6.patch"
  echo "bbrv3 patches applied"
  echo "Enabling networking configs"
  apply_conf "${GITHUB_WORKSPACE}/.github/configs/networking.fragment"
fi

if [[ "$USE_PERF" == "true" ]]; then
  cd "$KERNEL_ROOT/common"
  set -euo pipefail
  KERNEL_VERSION_NUM="${KERNEL_VERSION}"
  MIN_VERSION="5.16"

  patch -p1 --forward < "$KERNEL_PATCHES/common/optimized_mem_operations.patch"
  patch -p1 --forward < "$KERNEL_PATCHES/common/file_struct_8bytes_align.patch"
  patch -p1 --forward < "$KERNEL_PATCHES/common/reduce_cache_pressure.patch"
  patch -p1 --forward < "$KERNEL_PATCHES/common/mem_opt_prefetch.patch"

  if [ "$(printf '%s\n' "$KERNEL_VERSION_NUM" "$MIN_VERSION" | sort -V | tail -n1)" = "$KERNEL_VERSION_NUM" ]; then
    patch -p1 --forward < "$KERNEL_PATCHES/common/optimise_memcmp.patch"
  elif [ "$(printf '%s\n' "$KERNEL_VERSION_NUM" "5.11" | sort -V | tail -n1)" = "$KERNEL_VERSION_NUM" ]; then
    sed \
      -e 's/SYM_FUNC_START(__pi_memcmp)/SYM_FUNC_START_WEAK_PI(memcmp)/' \
      -e 's/SYM_FUNC_END(__pi_memcmp)/SYM_FUNC_END_PI(memcmp)/' \
      -e 's/SYM_FUNC_ALIAS_WEAK(memcmp, __pi_memcmp)/EXPORT_SYMBOL_NOKASAN(memcmp)/' \
      "$KERNEL_PATCHES/common/optimise_memcmp.patch" | patch -p1 --forward
  else
    echo "Optimised memcmp patch not found!"
  fi

  patch -p1 --forward < "$KERNEL_PATCHES/common/minimise_wakeup_time.patch"
  patch -p1 --forward < "$KERNEL_PATCHES/common/int_sqrt.patch"
  patch -p1 --forward < "$KERNEL_PATCHES/common/force_tcp_nodelay.patch"
  patch -p1 --forward < "$KERNEL_PATCHES/common/reduce_gc_thread_sleep_time.patch"
  patch -p1 --forward < "$KERNEL_PATCHES/common/add_timeout_wakelocks_globally.patch"
  patch -p1 --forward < "$KERNEL_PATCHES/common/f2fs_reduce_congestion.patch"
  patch -p1 --forward < "$KERNEL_PATCHES/common/reduce_freeze_timeout.patch"

  if [ "$(printf '%s\n' "$KERNEL_VERSION_NUM" "$MIN_VERSION" | sort -V | head -n1)" = "$KERNEL_VERSION_NUM" ]; then
    patch -p1 --forward < "$KERNEL_PATCHES/common/clear_page_16bytes_align.patch"
  else
    sed \
      -e 's/SYM_FUNC_START_PI(clear_page)/SYM_FUNC_START_PI(__pi_clear_page)/' \
      "$KERNEL_PATCHES/common/clear_page_16bytes_align.patch" | patch -p1 -F3 --forward
  fi

  for p in add_limitation_scaling_min_freq re_write_limitation_scaling_min_freq adjust_cpu_scan_order; do
    echo "Patching $p.patch"
    patch -p1 -F3 --forward < "$KERNEL_PATCHES/common/$p.patch"
  done

  echo "Patching avoid_extra_s2idle_wake_attempts.patch"
  FILE="drivers/base/power/wakeup.c"
  if grep -q "^void pm_system_wakeup(void)" "$FILE"; then
    if sed -n '/^void pm_system_wakeup(void)/,/^}/p' "$FILE" | grep -q 'suspend_abort_fs_sync();'; then
      sed -i '/^void pm_system_wakeup(void)/,/^}/{
        /suspend_abort_fs_sync();/d
      }' "$FILE"
    fi
  fi
  patch -p1 -F3 --forward < "$KERNEL_PATCHES/common/avoid_extra_s2idle_wake_attempts.patch"

  for p in disable_cache_hot_buddy f2fs_enlarge_min_fsync_blocks increase_ext4_default_commit_age increase_sk_mem_packets reduce_pci_pme_wakeups silence_irq_cpu_logspam silence_system_logspam use_unlikely_wrap_cpufreq; do
    echo "Patching $p.patch"
    patch -p1 -F3 --forward < "$KERNEL_PATCHES/common/$p.patch"
  done

  echo "[+] Other patches applied"
fi
