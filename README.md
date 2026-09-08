# apollo-mainline-android

Route (M1) engineering: turn the **apollo (Redmi K30S Ultra / Xiaomi Mi 10T, SM8250/kona) pmOS/mainline kernel** that is verified to boot on-device into a minimal smoke-test pipeline that can be booted by the Android framework.

The goal is not a fully working AOSP build, but a decidable milestone M1: **the mainline kernel can boot Android init / reach `adb shell`**.

## Contents
| Path | Purpose |
|---|---|
| `configs/android.fragment` | Linux kernel "Android-ification" Kconfig fragment (binder / dmabuf-heaps / PSI / SELinux …) |
| `bootimg/apollo.conf` | apollo boot image parameters (header v2, base/offset, cmdline, embedded DTB) |
| `scripts/prepare-prebuilt.sh` | [Recommended] handle the official pmOS 7.1 boot.img: unpack → kernel + dtb + Android readiness |
| `scripts/check-android-config.sh` | read the embedded config from the kernel Image to check whether Android symbols (binder etc.) are present |
| `scripts/ikconfig_extract.py` | extract the embedded .config from the kernel Image (CONFIG_IKCONFIG) |
| `scripts/split-appended-dtb.py` | split the appended DTB from the tail of the Image |
| `scripts/fetch-base.sh` | fetch base kernel source (for source rebuild) |
| `scripts/build.sh` | merge android.fragment → build `Image` + apollo DT (for source rebuild) |
| `scripts/assemble-bootimg.sh` | use `mkbootimg` to assemble kernel+dtb+ramdisk into a `fastboot boot`-able boot.img |
| `scripts/extract-bootimg-params.sh` | unpack a stock boot.img to verify the real boot header parameters |
| `docs/M1-checklist.md` | P0–P4 smoke-test checklist |
| `docs/DIAGNOSIS-7.1-recompile.md` | diagnosis: why the "recompiled 7.1" doesn't boot |
| `.github/workflows/prep-prebuilt-bootimg.yml` | CI: input pmOS boot.img + Android ramdisk → auto-produce AOSP boot.img |
| `.github/workflows/build.yml` | CI: source rebuild (BASE_KERNEL must be your boot-confirmed source) |

## Key insight
The official pmOS 7.1 ready-to-flash ROM kernel boots fine (touch + display working); but the kernel recompiled by the Action in your GitHub repo 7.1 branch is **not an Android kernel** (`apollo_defconfig` has `CONFIG_ANDROID` / `CONFIG_DMABUF_HEAPS` / `CONFIG_PSI` all set-not-set), and it has no boot.img packaging, so it cannot boot. See `docs/DIAGNOSIS-7.1-recompile.md`.

## Quick start A (recommended, prebuilt-first, no toolchain needed)
```bash
# ① process the official pmOS 7.1 boot.img
sudo apt install -y android-tools-unpackbootimg android-tools-mkbootimg
PMOS_BOOTIMG=/path/pmOS-7.1-boot.img
RAMDISK=/path/lineage.initramfs.img.gz \
DTB=<your-extracted apollo dtb> ./scripts/prepare-prebuilt.sh
# ② assemble the AOSP boot.img (①+② can also be done by GitHub Action prep-prebuilt-bootimg.yml)
RAMDISK=/path/android.ramdisk.gz DTB=<dtb> IMAGE=<kernel> ./scripts/assemble-bootimg.sh
# ③ smoke test (no flashing)
fastboot boot mainline-boot.img
```
Note: verify with `scripts/check-android-config.sh` that the official pmOS kernel already contains binder; if not, use Quick start B.

## Quick start B (source rebuild, only when A shows binder is missing)
```bash
export BASE_KERNEL=https://<your boot-confirmed pmOS/mainline kernel source>  # critical! default placeholder will fail
export BASE_REF=<branch>
./scripts/build.sh
RAMDISK=/path/lineage.ramdisk.cpio.gz DTB=kernel/out/arch/arm64/boot/dts/qcom/sm8250-xiaomi-apollo.dtb ./scripts/assemble-bootimg.sh
fastboot boot mainline-boot.img
```

## Next-step deliverable check
Check off the items in `docs/M1-checklist.md`; the core decision point is **`fastboot boot` under P3**.

## Scope and notes
- If the official pmOS kernel already carries binder (verifiable via ikconfig), repackaging it into an AOSP boot.img is the shortest path.
- The boot header defaults to header v2 (LineageOS sm8250-common non-VAB); if a package is vendor_boot/header v3/4, rely on `unpackbootimg` to verify.
- SukiSU/SUSFS, 1% battery fix and other 4.19 vendor-specific logic is not directly reusable on mainline and is out of scope here.