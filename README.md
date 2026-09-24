# xxKERNEL

Personal-use custom GKI kernel builder for **Android 15 / Kernel 6.6 LTS**.

Target SoC: `4x Cortex-A55 (LITTLE) + 4x Cortex-A78 (big)`, `ARMv8.2-a`.
Tuned with `-march=armv8.2-a+crypto+fp16+dotprod+rcpc+dcpop -mtune=cortex-a78` (`.github/scripts/compile.sh`) plus `-mcpu/-mtune=cortex-a78` for `ksu.o` (`backslashxx_hooks/cpu_optimization.patch`).

## Workflow

* Entry: `.github/workflows/main.yml` — `workflow_dispatch` `6.6-lts` (+ `flavor: perf|battery`, `create_release`), calls reusable `.github/workflows/build.yml`.
* Inputs: `kernelsu_variant (xxksu)`, `flavor`, `version`, `build_time`, `enable_nomount (disabled/master/dev)`, `droidspaces (off/678/123/345)`, `droidspaces_ntsync`, `use_bbg`, `use_networking (BBRv3)`, `use_perf`, `create_release`.
* Source: `repo init -b common-<android>-<kver>-lts` (LTS tracking, actual `SUBLEVEL` extracted from `common/Makefile` to `ACTUAL_SUBLEVEL` for artifact naming) + `repo sync` in `$KERNEL_ROOT/<android>-<kver>-lts`, cached via `actions/cache` keyed `kernel-source-<android>-<kver>-lts-<MANIFEST_HASH>`, stale keys deleted.
* Deps: `AnyKernel3 (sohan-f/cuscoi)`, `WildKernels/kernel_patches`, Bazel/Kleaf `//common:kernel_aarch64_autofdo_dist --config=fast`.
* Config engine: `.github/scripts/kernel-config.sh:apply_line()` — idempotent `CONFIG_X=y/m/str` + `# CONFIG_X is not set` handling. Baseline `gki_defconfig` diffed to `ksu.fragment` for Bazel `--defconfig_fragment`.
* Flavor overlays (`.github/configs/`): `ksu-base.fragment` (common) + `perf.fragment` (`HZ_300`, full `PREEMPT`) or `battery.fragment` (`HZ_250`, `PREEMPT_VOLUNTARY`).
* Stock spoof: `config/stock_defconfig` (6.6.87 base, `arch/arm64`) + `kernel/Makefile config_data` rewrite — currently disabled (`if: false`).
* Patches in `backslashxx_hooks/` applied after `KernelSU/setup.sh (backslashxx/master)`:
  * `manual_hooks.patch` — `fs/exec.c, fs/open.c, fs/stat.c, kernel/reboot.c` manual KSU hooks.
  * `cpu_optimization.patch` — `CFLAGS_ksu.o += -mcpu=cortex-a78 -mtune=cortex-a78`, block `moto_sched`, builtin `kernelsu_builtin_init`.
  * `thermal_patch.patch` — `thermal_helpers.c`: `-273000` -> `25000` safe fallback for broken sensors.
* Base block (`ksu-base.fragment`): `CONFIG_KSU, TMPFS_XATTR/ACL, CC_OPTIMIZE_FOR_PERFORMANCE, AUTOFDO_CLANG, LTO_CLANG_THIN, NO_HZ_IDLE, CPU_IDLE_GOV_MENU, CPU_FREQ_GOV_SCHEDUTIL, UCLAMP, SLUB_CPU_PARTIAL, PM_AUTOSLEEP/WAKELOCKS, CPU/DEVFREQ_THERMAL, LRU_GEN, F2FS_COMPRESSION, BPF_JIT_ALWAYS_ON, KASAN=n, SLUB_DEBUG=n, FTRACE=n, DEBUG_MISC=n`.
* Optional stages (`features.sh`):
  * `NoMount (maxsteeel/dev)` if `enable_nomount != disabled`.
  * `Droidspaces-OSS SYSVIPC kABI` + `SYSVIPC, POSIX_MQUEUE, IPC/PID_NS, DEVTMPFS, IP_SET, XT_*` + `BINFMT_*` x86_64 emu + `NTSync (Goldzxcbug)` if enabled.
  * `BBG (vc-teahouse/Baseband-guard)` + `CONFIG_BBG=y` + `security/Kconfig LSM` inject.
  * `BBRv3 + WIREGUARD + CAKE/FQ_CODEL + IP_SET full` if `use_networking`.
  * `WildKernels perf` (~20 patches: `mem_operations, file_struct_align, memcmp, clear_page, min_freq_scaling, cpu_scan_order, s2idle, f2fs/ext4, gc, wakelocks`) if `use_perf`.
* Release: `BUILD.bazel` ABI bypass (`protected_exports_list`/`kmi_symbol_list` strip), `scripts/setlocalversion` custom `version` or `android15-8-g<HASH>-ab<BID>`, `mkcompile_h UTS_VERSION` + `KBUILD_BUILD_TIMESTAMP/USER=sohan/HOST=cuscoi`, `retry(3x)` compile with `build-logs/compile-attempt-N.log`, `Image` (located via `find`) into `AnyKernel3/`, upload `*-<flavor>-AnyKernel3` artifact, optional GitHub Release zip (`create_release`).

## Layout

```
config/stock_defconfig          # 6.6.87 arm64 reference, for /proc/config.gz spoofing
backslashxx_hooks/              # manual_hooks, cpu_optimization, thermal patches
.github/workflows/main.yml     # user-facing dispatch (6.6-lts)
.github/workflows/build.yml    # thin orchestrator (~170 lines, uses: + bash calls)
.github/scripts/*.sh            # setup, manifest, sync, ksu, features, version, compile, package
.github/scripts/kernel-config.sh # apply_line() helper (sourced, not inlined)
.github/configs/*.fragment      # ksu-base + perf|battery overlays, droidspaces, binfmt, networking
```
