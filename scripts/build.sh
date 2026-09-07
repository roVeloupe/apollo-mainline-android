#!/usr/bin/env bash
# build.sh
#
# R 路线 M1：拉取 base 内核 -> 合入 android.fragment -> 编译 Image + apollo DT。
#
# 环境依赖（arm64 交叉工具链），首选 LLVM/Clang：
#   sudo apt install -y clang lld llvm flex bison libssl-dev libncurses-dev
#                           bc cpio util-linux python3
# 或 GCC:
#   sudo apt install -y gcc-aarch64-linux-gnu
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

KERNEL_DIR="${KERNEL_DIR:-kernel}"
O_DIR="${O_DIR:-out}"
DTB_NAME="${DTB_NAME:-qcom/sm8250}"
DEFCONFIG="${DEFCONFIG:-}"
# 可选：直接以 pmOS 已验证 config 文件作基座（比 defconfig 更能保持"能开机"的配置）
PMOS_CONFIG="${PMOS_CONFIG:-}"

export ARCH="${ARCH:-arm64}"
export CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"
# LLVM 存在则用 LLVM；否则回退 GCC：
if command -v clang >/dev/null 2>&1 && [ -z "${FORCE_GCC:-}" ]; then
  export LLVM=1
  CROSS_COMPILE=""
  echo "[build] 使用 LLVM/Clang 工具链"
else
  unset LLVM
  echo "[build] 使用 GCC 工具链: ${CROSS_COMPILE}"
fi

echo "[build] 拉取/更新 base 内核"
"$SCRIPT_DIR/fetch-base.sh"
cd "$KERNEL_DIR"

# 基座配置：优先用 pmOS 已验证 config 文件，否则用 base 自带 qcom/defconfig
if [ -n "$PMOS_CONFIG" ]; then
  echo "[build] 以 pmOS 已验证 config 作基座: $PMOS_CONFIG"
  rm -rf "$O_DIR"; mkdir -p "$O_DIR"
  cp "$PMOS_CONFIG" "$O_DIR/.config"
  make O="$O_DIR" olddefconfig
elif [ -z "$DEFCONFIG" ]; then
  if [ -f arch/${ARCH}/configs/qcom_defconfig ]; then
    DEFCONFIG=qcom_defconfig
  else
    DEFCONFIG=defconfig
  fi
  echo "[build] DEFCONFIG=${DEFCONFIG}"
  make O="$O_DIR" "$DEFCONFIG"
fi
echo "[build] 合入 AOSP 必要配置片段"
scripts/kconfig/merge_config.sh -O "$O_DIR" "$O_DIR/.config" "$ROOT_DIR/configs/aosp-pmos610.fragment"
echo "[build] 规范化配置"
make O="$O_DIR" savedefconfig

echo "[build] 编译 Image 与 ${DTB_NAME}"
make O="$O_DIR" Image
if ! make O="$O_DIR" "${DTB_NAME}" >/dev/null 2>&1; then
  echo "[build] 直接 make ${DTB_NAME} 失败，尝试 dtbs:"
  make O="$O_DIR" dtbs
fi

ls -l "$O_DIR/arch/${ARCH}/boot/Image"* 2>/dev/null || true
echo "[build] 完成。产物:"
echo "  Image : $O_DIR/arch/${ARCH}/boot/Image"
find "$O_DIR/arch/${ARCH}/boot/dts" -name "*.dtb" -path "*qcom*" 2>/dev/null | head