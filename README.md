# apollo-mainline-android

R 路线（M1）工程化：把 **apollo（Redmi K30S Ultra / Xiaomi Mi 10T, SM8250/kona）实测能开机的 pmOS/mainline 内核**，改造成"能被 Android 框架引导"的最小冒烟流水线。

目标不是整套可用 AOSP，而是达成一个可判定的里程碑 M1：**mainline 内核能引导 Android init / 可 `adb shell`**。

## 目录
| 路径 | 作用 |
|---|---|
| `configs/android.fragment` | Linux 内核 "Android 化" Kconfig 片段（binder / dmabuf-heaps / PSI / SELinux …） |
| `bootimg/apollo.conf` | apollo boot image 参数（header v2、base/offset、cmdline、DTB 内嵌） |
| `scripts/prepare-prebuilt.sh` | 【推荐】处理官方 pmOS 7.1 的 boot.img：解包 → kernel + dtb + Android 就绪度 |
| `scripts/check-android-config.sh` | 从内核 Image 读内嵌 config，判定是否已带 binder 等 Android 符号 |
| `scripts/ikconfig_extract.py` | 提取内核 Image 内嵌 .config（CONFIG_IKCONFIG） |
| `scripts/split-appended-dtb.py` | 从 Image 尾部切出追加的 DTB |
| `scripts/fetch-base.sh` | 拉取 base 内核源码（源码重编时用） |
| `scripts/build.sh` | 合入 android.fragment → 编译 `Image` + apollo DT（源码重编时用） |
| `scripts/assemble-bootimg.sh` | 用 `mkbootimg` 把 kernel+dtb+ramdisk 组为可 `fastboot boot` 的 boot.img |
| `scripts/extract-bootimg-params.sh` | 解包 stock boot.img 核对真实 boot 头参数 |
| `docs/M1-checklist.md` | P0–P4 冒烟判定清单 |
| `docs/DIAGNOSIS-7.1-recompile.md` | 诊断：为何"二次编译的 7.1"启动不了 |
| `.github/workflows/prep-prebuilt-bootimg.yml` | CI：输入 pmOS boot.img + Android ramdisk → 自动产出 AOSP boot.img |
| `.github/workflows/build.yml` | CI：源码重编（需 BASE_KERNEL 是你实测能开机的源码） |

## 关键认知
官方 pmOS 7.1 即刷 ROM 的 kernel 能开机（触摸显示正常）；而你 gh 仓库 7.1 分支 Action 二次编译的 kernel **不是 Android 内核**（`apollo_defconfig` 里 `CONFIG_ANDROID` / `CONFIG_DMABUF_HEAPS` / `CONFIG_PSI` 全部为 set-not-set），且无 boot.img 打包，所以起不来。详见 `docs/DIAGNOSIS-7.1-recompile.md`。

## 快速开始 A（推荐，预编译优先，无需备工具链）
```bash
# ① 处理官方 pmOS 7.1 的 boot.img
sudo apt install -y android-tools-unpackbootimg android-tools-mkbootimg
PMOS_BOOTIMG=/path/pmOS-7.1-boot.img
RAMDISK=/path/lineage.initramfs.img.gz \
DTB=<解出的apollo dtb> ./scripts/prepare-prebuilt.sh
# ② 组 AOSP boot.img（①②也可由 GitHub Action prep-prebuilt-bootimg.yml 代做）
RAMDISK=/path/android.ramdisk.gz DTB=<dtb> IMAGE=<kernel> ./scripts/assemble-bootimg.sh
# ③ 冒烟（不刷写）
fastboot boot mainline-boot.img
```
注意：官方 pmOS kernel 需要用 `scripts/check-android-config.sh` 确认是否已带 binder；未带则走"快速开始 B"。

## 快速开始 B（源码重编，仅当选 A 判到缺 binder 时）
```bash
export BASE_KERNEL=https://<你实测能开机的 pmOS/mainline 内核源码>  # 关键！默认占位会失败
export BASE_REF=<分支>
./scripts/build.sh
RAMDISK=/path/lineage.ramdisk.cpio.gz DTB=kernel/out/arch/arm64/boot/dts/qcom/sm8250-xiaomi-apollo.dtb ./scripts/assemble-bootimg.sh
fastboot boot mainline-boot.img
```

## 下一步产出判定
按 `docs/M1-checklist.md` 逐项勾选；核心判定在 **P3 的 `fastboot boot`**。

## 边界与注意
- 官方 pmOS kernel 若已带 binder（ikconfig 可读证），把它重打成 AOSP boot.img 是最短路。
- boot 头默认 header v2（LineageOS sm8250-common 非 VAB）；若手头包是 vendor_boot/header v3/4，以 `unpackbootimg` 解包为准。
- SukiSU/SUSFS、1% 电量修复等 4.19 vendor 专属逻辑在 mainline 上不直接复用，本仓库不覆盖。