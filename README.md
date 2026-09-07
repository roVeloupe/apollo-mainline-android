# apollo-mainline-android

R 路线（M1）工程化：把 **apollo（Redmi K30S Ultra / Xiaomi Mi 10T, SM8250/kona）实测能开机的 pmOS/mainline 内核**，改造成"能被 Android 框架引导"的最小冒烟流水线。

目标不是整套可用 AOSP，而是达成一个可判定的里程碑 M1：**mainline 内核能引导 Android init / 可 `adb shell`**。

## 目录
| 路径 | 作用 |
|---|---|
| `configs/android.fragment` | Linux 内核 "Android 化" Kconfig 片段（binder / dmabuf-heaps / PSI / SELinux …） |
| `bootimg/apollo.conf` | apollo boot image 参数（header v2、base/offset、cmdline、DTB 内嵌） |
| `scripts/fetch-base.sh` | 拉取 base 内核源码 |
| `scripts/build.sh` | 合入配置 → 编译 `Image` + apollo DT |
| `scripts/assemble-bootimg.sh` | 用 `mkbootimg` 组一个可 `fastboot boot` 的 boot.img |
| `scripts/extract-bootimg-params.sh` | 解包 stock boot.img，核对真实 boot 头参数 |
| `docs/M1-checklist.md` | P0–P4 冒烟判定清单 |
| `.github/workflows/build.yml` | 手动触发构建并上传产物 |

## 快速开始（本机）
```bash
# 1) 指定你的 base 内核（务必是你实测能开机的那份）
export BASE_KERNEL=https://<你的 pmOS/mainline 内核源码>
export BASE_REF=<分支>
export KERNEL_DIR=kernel

# 2) 拉 base + 合入配置 + 编译
sudo apt install -y gcc-aarch64-linux-gnu flex bison libssl-dev libncurses-dev bc cpio \
                     android-tools-mkbootimg android-tools-unpackbootimg
./scripts/build.sh

# 3) 组装冒烟 boot.img（RAMDISK 放一份 Lineage/官方 ramdisk）
RAMDISK=/path/to/lineage.ramdisk.cpio.gz \
DTB=kernel/out/arch/arm64/boot/dts/qcom/sm8250-xiaomi-apollo.dtb \
./scripts/assemble-bootimg.sh

# 4) 冒烟（不刷写）
fastboot boot mainline-boot.img
```

## 下一步产出判定
按 `docs/M1-checklist.md` 逐项勾选；核心判定在 **P3 的 `fastboot boot`**。

## 边界与注意
- **base 内核是成败关键**：`BASE_KERNEL` 必须指向你实测能在 apollo 开机点亮触摸的源码；CI 默认值是占位，会构建失败。
- boot 头默认 header v2（LineageOS sm8250-common 非 VAB）；若手头 MIUI 官方 Android 12 是 vendor_boot/header v3/4，以 `unpackbootimg` 解包为准。
- SukiSU/SUSFS、1% 电量修复等 4.19 vendor 专属逻辑在 mainline 上不直接复用，本仓库不覆盖。
- 详见 `docs/` 与可行性报告 v2.0。