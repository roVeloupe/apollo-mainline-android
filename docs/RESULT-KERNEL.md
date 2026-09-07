# 交付成果：AOSP-就绪的 pmOS 6.11 内核（已二进制核验）

## 产物（/workspace/apollo-aosp-kernel/）
| 文件 | 说明 |
|---|---|
| `Image`          | 编译好的 AArch64 内核镜像（约 46MB，kernel 6.11.0） |
| `dtb/sm8250-mtp.dtb` | 通用 kona 板级设备树（该 fork 无 apollo 专用 DT） |
| `dtb/sm8250-hdk.dtb` | 备选通用 DT |
| `original-pmos-6.11.config` | pmOS 官方 `config-postmarketos-qcom-sm8250.aarch64`（已验证原始 config） |

## 构建来源（溯源）
- 源码：`gitlab.com/sm8250-mainline/linux` @ tag `sm8250-6.11.0`
- 即 pmOS 设备包 `linux-postmarketos-qcom-sm8250`（pkgver=6.11.0）所打包、用户实测能在 apollo 开机的内核同源
- 基座 config：pmOS 已验证 config + `configs/aosp-pmos610.fragment`
- 工具链：aarch64-linux-gnu-gcc 11.4，`make O=out Image dtbs`

## 全面核验结果（读取产物二进制内嵌 IKCFG 证明，非推断）
```
CONFIG_ANDROID_BINDER_IPC=y     # binder 主驱动
CONFIG_ANDROID_BINDERFS=y       # AOSP init 挂载 binderfs（原 pmOS 缺失，已补）
CONFIG_DMABUF_HEAPS_SYSTEM=y    # gralloc/SurfaceFlinger 渲染 System heap（原缺失，已补）
CONFIG_PSI=y                    # Android 内存压力信息
CONFIG_IKCONFIG=y               # 内嵌 config（/proc/config.gz 可读）
```
即：这颗内核**配置层面已达 AOSP 就绪**，且是从"实测能开机"的同一来源内核构建，风险最低。

## 还差的两样设备相关输入（无法由本沙箱自动提供）
1. **Android ramdisk**：LineageOS/官方 ROM 的 `boot.img` 解出（mirrorbits 有 bot 防护，需本机/浏览器下载）。
2. **能点亮 apollo 面板的 dtb**：此 fork**没有 apollo 专用 DT**（已核实，仅 mtp/hdk/oneplus/xperia/elish/pipa）。你实测能开机时用的那份 dtb 正是关键（它在你本机那份能开机的 boot 里）。

## 组装 AOSP boot.img（在本机执行）
```bash
# 用你那份能开机的 boot 解出: kernel=Image(用本内核替换), ramdisk, dtb, 真实参数
unpackbootimg -i 你的boot.img -o unpack
# 用本内核 Image 重打包（param 以你真实 boot 为准，示例 header v2 + append dtb）
mkbootimg --header_version 2 \
  --kernel /workspace/apollo-aosp-kernel/Image \
  --ramdisk unpack/*-ramdisk.gz \
  --dtb 你的apollo.dtb \
  --base 0x00000000 --pagesize 4096 \
  -o aosp-boot.img
fastboot boot aosp-boot.img
```

## 结论
内核本体已构建并核验为 AOSP 就绪（binderfs + System heap 已编译进二进制）。能否开机到 Android 首屏，取决于把**能驱动 apollo 面板的 dtb + Android ramdisk** 与你手上这台（用户已具备）组起来做 `fastboot boot`。沙箱侧已完成全部可自动化的查证与构建。