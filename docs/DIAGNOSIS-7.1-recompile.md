# 诊断：为什么"二次编译的 7.1"启动不了

## 现象
- 官方 postmarketOS 7.1 即刷 ROM → 能开机，触摸显示正常（**好**）。
- 用 gh 仓库 `apollo-7.1` 分支的 Action 二次编译的 kernel → 黑屏/卡屏/fb，无法启动。

## 根因（已从仓库配置取证，非猜测）
`reVoleupo/kernel_xiaomi_apollo_5.10` 分支 `apollo-7.1` 的 `arch/arm64/configs/apollo_defconfig`，关键符号：

```
# CONFIG_ANDROID is not set         # Android/binder 整个关闭
# CONFIG_DMABUF_HEAPS is not set    # dmabuf-heaps 关闭
# CONFIG_PSI is not set             # PSI 压力信息关闭
CONFIG_IKCONFIG=y  /  CONFIG_IKCONFIG_PROC=y  # 内嵌 config 开启
```

该分支 `build.yml` 只做：clang 编译 `apollo_defconfig` → 产出 `Image` + `apollo-sm8250.dtb`，**未做任何 AOSP boot.img 打包**。

## 结论
这份二次编译产物**本质上不是 Android 内核**（缺 binder/dmabuf-heaps/PSI），AOSP 起不来是必然；它离官方 pmOS 能开机 kernel 的差距是"Android 配置 + 正确 dtb + 打包"，不是版本号。

## 对策（本仓库落地）
- 优先走**预编译**：直接用官方 pmOS 那份能开机的 `boot.img` 的 kernel，重打 AOSP boot.img（`scripts/prepare-prebuilt.sh` + `scripts/assemble-bootimg.sh`，或 CI `prep-prebuilt-bootimg.yml`）。
- 官方 pmOS kernel 是否已带 binder，用 `scripts/check-android-config.sh` 判定（ikconfig 已开，可直接读）：
  - 已带 → 重打即可冒烟。
  - 未带 → 必须用 `configs/android.fragment` 合入后重新编译，且要确保 dtb/显示仍能点亮（这是豆包没做全的部分）。