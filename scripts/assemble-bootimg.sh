#!/usr/bin/env bash
# assemble-bootimg.sh
#
# 用 mkbootimg 组装一个可 fastboot boot 的 header v2 boot.img：
#   主线程 kernel 镜像 Image
#   + Android/Lineage ramdisk（用于 AOSP 冒烟）
#   + apollo 主设备树 dtb（内嵌，BOARD_INCLUDE_DTB_IN_BOOTIMG=true）
#
# 依赖:
#   sudo apt install -y android-tools-mkbootimg android-tools-unpackbootimg
#
# 用法:
#   RAMDISK=lineage_ramdisk.cpio.gz DTB=<dtb路径> ./scripts/assemble-bootimg.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CONF="${CONF:-$ROOT_DIR/bootimg/apollo.conf}"

# 必填输入
IMAGE="${IMAGE:-$ROOT_DIR/kernel/out/arch/arm64/boot/Image}"
RAMDISK="${RAMDISK:?请设置 RAMDISK 指向 Lineage/Android ramdisk}"
DTB="${DTB:?请设置 DTB 指向 apollo 主设备树 dtb}"
OUT="${OUT:-mainline-boot.img}"

# 从 conf 读取参数（支持多行 CMDLINE）
set -a; source "$CONF"; set +a

if ! command -v mkbootimg >/dev/null 2>&1; then
  echo "[bootimg] 未找到 mkbootimg，请先: sudo apt install -y android-tools-mkbootimg"
  exit 1
fi

echo "[bootimg] 组装 header v${BOARD_BOOT_HEADER_VERSION} boot.img"
echo "  Image  : ${IMAGE}"
echo "  Ramdisk: ${RAMDISK}"
echo "  DTB    : ${DTB}"
echo "  Out    : ${OUT}"

mkbootimg \
  --header_version "$BOARD_BOOT_HEADER_VERSION" \
  --kernel "$IMAGE" \
  --ramdisk "$RAMDISK" \
  --dtb "$DTB" \
  --base "$BOARD_KERNEL_BASE" \
  --pagesize "$BOARD_KERNEL_PAGESIZE" \
  --kernel_offset "$BOARD_KERNEL_OFFSET" \
  --ramdisk_offset "$BOARD_RAMDISK_OFFSET" \
  --second_offset "$BOARD_SECOND_OFFSET" \
  --tags_offset "$BOARD_TAGS_OFFSET" \
  --cmdline "$BOARD_KERNEL_CMDLINE" \
  -o "$OUT"

echo "[bootimg] 完成: ${OUT}"
echo "[bootimg] 冒烟测试命令:"
echo "  fastboot boot ${OUT}"
echo "  (不写入分区；AVB/dtbo 如需处理见 README/附录)"