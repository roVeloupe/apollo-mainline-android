#!/usr/bin/env bash
# prepare-prebuilt.sh
#
# R 路线 M1 · 预编译优先：处理"官方 pmOS 7.1 即刷 ROM 的 boot.img"，
# 得到可重打包成 AOSP boot.img 的三要素: kernel Image + dtb + Android 就绪度判定。
#
# 用法: PMOS_BOOTIMG=/path/pmOS-boot.img ./scripts/prepare-prebuilt.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PMOS_BOOT="${PMOS_BOOTIMG:?请设置 PMOS_BOOTIMG 指向官方 pmOS 7.1 的 boot.img}"
WORK="${WORK:-pmos_unpacked}"

command -v unpackbootimg >/dev/null 2>&1 || { echo "[prep] 缺少 unpackbootimg: sudo apt install -y android-tools-unpackbootimg"; exit 1; }

echo "=== 1/3 解包 pmOS boot.img ==="
rm -rf "$WORK"; mkdir -p "$WORK"
unpackbootimg -i "$PMOS_BOOT" -o "$WORK"
ls -la "$WORK"

# 定位内核镜像产物
KERNEL_IMAGE=""
for c in "$WORK"/*kernel* "$WORK"/*zImage* "$WORK"/Image*; do
  [ -f "$c" ] && KERNEL_IMAGE="$c" && break
done
[ -z "$KERNEL_IMAGE" ] && { echo "[prep] 未在解包目录找到 kernel 产物，请人工指定"; exit 1; }
echo "  内核镜像: $KERNEL_IMAGE"

echo "=== 2/3 判定 Android 就绪度(需 CONFIG_IKCONFIG) ==="
"$SCRIPT_DIR/check-android-config.sh" "$KERNEL_IMAGE" || true

echo "=== 3/3 切分内嵌 DTB(取 apollo 那份) ==="
"$SCRIPT_DIR/split-appended-dtb.py" "$KERNEL_IMAGE" "${WORK}/dtbs" || true

cat <<EOF

完成。下一步（需你的 Android ramdisk）:
  RAMDISK=/path/to/lineage.ramdisk.cpio.gz \
  IMAGE=${KERNEL_IMAGE} \
  DTB=${WORK}/dtbs/<apollo那份>.dtb \
  ./scripts/assemble-bootimg.sh
  然后: fastboot boot mainline-boot.img
EOF