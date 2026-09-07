# apollo 在 mainline 上的真实状态（已查证）

> 本文档汇总本仓库在探索阶段对 "apollo(mi10T/K30S Ultra, SM8250/kona) mainline → AOSP" 的确定性事实，避免重复踩坑。

## 一、Android 配置：不是瓶颈（有力证据）
SM8250 mainline 内核 fork 的 `sm8250.config` 明确开启 Android 相关选项（供 Anbox/Waydroid/Android 用户态）：
```text
CONFIG_ANDROID=y
CONFIG_ANDROID_BINDER_IPC=y
CONFIG_ANDROID_BINDERFS=y
CONFIG_DMABUF_HEAPS=y        (+_CMA / _SYSTEM)
CONFIG_PSI=y
```
- 来源: `mainlining/linux` 分支 `nikroks/alioth`, `arch/arm64/configs/sm8250.config`
- 直链: https://raw.githubusercontent.com/mainlining/linux/nikroks/alioth/arch/arm64/configs/sm8250.config

结论：若 base 是这类 mainline kona 内核，**binder/dmabuf-heaps/PSI 已具备，可宿主 Android 用户态**。"缺 Android 内核能力"不是 apollo 失败的主因。

## 二、设备树：真正的瓶颈（硬证据）
`mainlining/linux` 分支 `nikroks/alioth` 的 `arch/arm64/boot/dts/qcom/` 下 sm8250 板级文件（11 个）：
```
sm8250-hdk.dts / sm8250-mtp.dts
sm8250-sony-xperia-edo-*.dts
sm8250-xiaomi-alioth.dts
sm8250-xiaomi-elish-{boe,common,csot}.dts
sm8250-xiaomi-pipa.dts
sm8250.dtsi
```
**没有 `sm8250-xiaomi-apollo.dts`**。官方 wiki 对 apollo 标注 `Mainline=no` / Not booting 与之一致。

结论：apollo 在 mainline 上没有可用的板级设备树。任何 mainline apollo 内核都必须**自行编写/移植 apollo DT（面板、触摸、IO 复用、电池/PMIC 等）**，这正是最难、也恰恰没有现成物料的环节。用户曾用的自定义 `apollo-sm8250.dts`（面板时序未验证）即属此类。

## 三、为何用户仓库 7.1 二次编译起不来
`reVoleupo/kernel_xiaomi_apollo_5.10` 分支 `apollo-7.1`：
- `apollo_defconfig` 中 `CONFIG_ANDROID` / `CONFIG_DMABUF_HEAPS` / `CONFIG_PSI` 均为 not set → 非 Android 内核
- `build.yml` 仅 clang 编译 `apollo_defconfig` → `Image` + `apollo-sm8250.dtb`，无 AOSP boot.img 打包
- 其 `apollo-sm8250.dts` 为自定义/未验证 DT

三重缺失（Android 配置 + DT 可靠度 + 打包）叠加导致黑屏/卡屏/fb。

## 四、可直接引用的外部资源
- mainline kona 内核(主分支, 含 Android 配置): https://github.com/mainlining/linux 分支 `nikroks/alioth`
- LineageOS apollon(sm8250 同系) 23.2 nightly: `https://mirrorbits.lineageos.org/full/apollon/20260905/` 内有 `recovery.img`、`lineage-23.2-*.zip`（zip 内含 boot.img，可作 Android ramdisk 来源）
  - 注意：mirrorbits 有 bot 防护，需在浏览器/本机下载，沙箱直连返回 403
- 设备参数(header v2 等)见 `bootimg/apollo.conf`

## 五、结论与建议
1. M1 价值：若你要验证"mainline 能否带 AOSP"，应**优先复用你实测能开机的 pmOS 内核**（它已有可用 DT），重打成 AOSP boot.img，而不是重新编译。
2. 若走源码重编：`BASE_KERNEL` 必须是你那份**能开机的内核源码**（其 DT 已验证）。用 `configs/android.fragment` 补齐 Android 配置，用 `scripts/assemble-bootimg.sh` 打包。
3. 若定要"从零 mainline AOSP on apollo"：真正的工作量在 **apollo 板级 DT 的 bring-up（尤其面板/触摸）**，这是数周级的硬件素材工作，非配置可解。