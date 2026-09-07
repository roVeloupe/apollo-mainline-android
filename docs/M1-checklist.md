# M1 冒烟测试判定清单 (docs/M1-checklist.md)

> 目标：判定 **mainline 内核能否引导 Android 框架（M1）**。
> 完成 P0–P3 即完成 M1。勾选项如下。

## P0 锁定能开机的基线
- [ ] 记录 base 内核源码 URL + 分支（本仓库 `BASE_KERNEL` / `BASE_REF`）
- [ ] 已备份可回滚的原厂/可用 ROM
- [ ] 备好调试手段（尽量 UART `ttyMSM0`；否则 last_kmsg/pstore + fastboot 状态灯）

## P1 内核 Android 化配置（configs/android.fragment）
- [ ] `CONFIG_ANDROID` / `CONFIG_ANDROID_BINDER_IPC` / `CONFIG_ANDROID_BINDERFS` 已开
- [ ] dmabuf-heaps（system + cma）已开（旧 5.10 若需兼容再补 `CONFIG_ION`）
- [ ] DEVTMPFS / cgroup / memcg / PSI 已开
- [ ] SELinux 开（首轮 permissive）
- [ ] 编译出 `Image` + apollo `*.dtb`

## P2 组最小 Android 启动链（bootimg/apollo.conf）
- [ ] 已 `unpackbootimg` 解包一份 Lineage/官方 `boot.img`，核对真实 header/pagesize/offset/cmdline
- [ ] 确认或覆盖 `BOARD_BOOT_HEADER_VERSION`（sm8250-common 非 VAB=2）
- [ ] 用 `assemble-bootimg.sh` 组装 `mainline-boot.img`（Image + ramdisk + dtb）
- [ ] 处理 AVB：临时 `fastboot boot` 一般不需；失败再替换当前 slot `vbmeta`
- [ ] 需要时刷 `dtbo.img`（32 MiB 分区）

## P3 最小冒烟测试（决定性）
- [ ] `fastboot boot mainline-boot.img`
- [ ] 等待 3–5 分钟，记录：是否进 Android / 是否 bootloader 屏 / 是否黑屏+震动发热
- [ ] 能 `adb shell` → **M1 达成**；否则抓 UART/last_kmsg 定性

### 判定与输出
- 能到 Android 或 adb shell → 有希望成立，进入 P4 显示优先级打点。
- 仍黑屏无震动无发热且 dmesg 早期挂死 → 记录"哪一层(内核/启动链/HAL)"，回锅查 base 与 loader 差异，勿继续空刷。

## P4 显示优先（M1 达成后）
- [ ] 确认 `/dev/dri/card0` 与 dpu/dsi 在 AOSP 加载下 probe
- [ ] 用 `drm-hwcomposer` 或 fallback 让 surfaceflinger 出画面
- [ ] 明确 M2 边界：音频(/WCD9380)、相机、WiFi(QCA6390)、RIL 属长周期 HAL，记录备忘

## 已知注意
- postmarketOS wiki 对 apollo 曾标注 Not booting / mainline=no；若你实测能点亮，以实测为准。
- SukiSU/SUSFS、1% 电量修复等 4.19 vendor 专属逻辑在 mainline 上**不直接复用**，本流水线不覆盖。