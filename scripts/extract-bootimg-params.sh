#!/usr/bin/env bash
# extract-bootimg-params.sh
#
# 解包 LineageOS/官方 stock boot.img，打印真实 boot 头参数，
# 供核对 / 覆盖 bootimg/apollo.conf 使用。
#
# 用法: BOOTIMG=/path/to/boot.img ./scripts/extract-bootimg-params.sh
set -euo pipefail

BOOTIMG="${BOOTIMG:?请设置 BOOTIMG 指向要解包的 boot.img}"
WORK="${WORK:-unpacked_boot}"

if ! command -v unpackbootimg >/dev/null 2>&1; then
  echo "[bootimg] 未找到 unpackbootimg，请先: sudo apt install -y android-tools-unpackbootimg"
  exit 1
fi

rm -rf "$WORK"; mkdir -p "$WORK"
unpackbootimg -i "$BOOTIMG" -o "$WORK"

echo "[bootimg] 解包完成: ${BOOTIMG}"
echo "  产物在 ${WORK}/, 关键参数:"
grep -rE "header version|page_size|kernel_offset|ramdisk_offset|second_offset|tags_offset|base|dtb" "$WORK" 2>/dev/null || ls -la "$WORK"
echo "[bootimg] 建议 cmdtline(截取返回): head -c 600 ${WORK}/boot.img-cmdline 2>/dev/null || cat ${WORK}/boot.img-cmdline"