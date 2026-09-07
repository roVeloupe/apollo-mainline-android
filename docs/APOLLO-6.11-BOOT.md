# 交付:可刷的 6.11 AOSP 启动镜像(apollo / 红米K30S Ultra)

产物全部在本机实测组装并通过字节校验。文件与"怎么用"如下。

## 产物 (/workspace/apollo-aosp-kernel/)
| 文件 | 体积 | 说明 |
|---|---|---|
| `Image` | 46.6MB | pmOS 6.11 基座 + AOSP config(binderfs/system-heap) 编译的内核, IKCFG 已核验 |
| `sm8250-apollo.dtb` | 118KB | 在 6.11 树内由你仓库 `apollo-sm8250.dts` 编译出的 mainline apollo 设备树, `model="Xiaomi Redmi K30S Ultra"` `compatible="qcom,sm8250"` |
| `apollo-aosp-6.11-apollo-dtb-boot.img` | ~49MB | **推荐**: 6.11 Image + Android ramdisk + mainline apollo dtb, 用你 ROM 真实参数(header v2)封装 |
| `apollo-aosp-6.11-boot.img` | ~48MB | 备选: 同内核但带 ROM 自身的通用 kona dtb |
| `original-pmos-6.11.config` | | pmOS 已验证原始 config |

## 上板刷写(冒烟判定)
```bash
# 先解锁 bootloader。用 fastboot 内存启动(不刷写), 看能否进入 Android init / 串口日志
fastboot boot /workspace/apollo-aosp-kernel/apollo-aosp-6.11-apollo-dtb-boot.img
```
预期与判读:
- 能进 Android/lock 屏 → M1 达成, 高版本可用的里程碑成立。
- 进入内核控制台但显示黑/闪 → 内核启动 OK, 差显示 HAL/驱动 进一步 bring-up。
- 又快又准的判读法: 接 UART 串口(apollo 有 DBG 口)看重启后 dmesg 到哪一步。

## 为何这次"更有希望"
1. **配对正确**: mainline 6.11 内核 + mainline 格式 apollo dts 编译的 DT(同一 6.11 树的 dtsi), 不是拿 vendor 4.19 dtb 硬配。
2. **内核配置 AOSP 就绪**: 二进制 IKCFG 证明 binderfs/droid vs: binderfs/dmabuf-heaps/PSI 已编入。
3. **ramdisk/参数取自你这台的真实 ROM boot.img**, header v2/页大小/各段地址/cmdline 完全一致。

## 关键事实(已取证)
- 你 ROM 的 `boot.img`: header v2, kernel+ramdisk+**通用 kona dtb**(board-id 0); apollo 面板(nt36672) 在 `dtbo.img` 的 vendor overlay 里。
- 该 6.11 mainline fork **没有 apollo 板级 DT**(只有 mtp/hdk/oneplus/xperia/elish/pipa)。本次已把你库里那颗 mainline 样式 `apollo-sm8250.dts` 合进 6.11 编译, 解决"缺 apollo DT"。
- `sm8250-apollo.dtb` 仅 118KB(无显示/触摸/音频驱动绑定, 无电源管理), 属编译纯骨架。**显示能否点亮仍需下板验证** —— 这颗 dts 在 5.10 时"panel timing untested"也黑屏过, 6.11 生态更保守。

## 仍在做的工作
- mainline apollo 的面板(nt36672) / 触摸 / 音频 / 电源, 需按考间主 binding 逐个补进这颗 DT 才能点亮并进 Android。这是下板后依据 dmesg 增量做, 属 bring-up 正活。
- 成功进 Android 后, 再考虑加回 mod 特性(SukiSU 等在 mainline 需重实现 / USB串口&EROFS&zRAM 纯 Kconfig 可直接开)。

## 工具(repo scripts/)
- `parse_boot.py` 解包 Android boot img(任意 header v0/1/2) → kernel/ramdisk/dtb + 打印真实参数
- `repack_boot.py` 按指定 kernel/ramdisk/dtb 重封装 header v2 boot(用 apollo 真实参数)