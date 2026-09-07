#!/usr/bin/env bash
# fetch-base.sh
#
# 拉取 base 内核源码（R 路线 M1）。
#
# 关键：BASE_KERNEL 必须指向"你实测能在 apollo 上开机点亮触摸"的 pmOS/base 内核源码。
#       默认值只是占位，请务必用你自己的源码覆盖。
set -euo pipefail

BASE_KERNEL="${BASE_KERNEL:-https://github.com/sm8250-mainline/linux}"
BASE_REF="${BASE_REF:-sm8250}"
KERNEL_DIR="${KERNEL_DIR:-kernel}"

if [ -z "$BASE_REF" ]; then
  echo "[fetch-base] !!! BASE_KERNEL=${BASE_KERNEL}"
  echo "[fetch-base] 提示: 请设置 BASE_KERNEL 为你实测能开机的 pmOS mainline 内核源码，"
  echo "[fetch-base]       并设置 BASE_REF 为对应分支/标签 (示例: BASE_REF=master)。"
fi

if [ -d "$KERNEL_DIR/.git" ]; then
  echo "[fetch-base] ${KERNEL_DIR} 已存在，更新引用..."
  git -C "$KERNEL_DIR" fetch --depth=1 origin "$BASE_REF"
else
  echo "[fetch-base] 克隆 ${BASE_KERNEL}@{${BASE_REF}} -> ${KERNEL_DIR}"
  git clone --depth=1 -b "$BASE_REF" "$BASE_KERNEL" "$KERNEL_DIR"
fi

echo "[fetch-base] 完成: ${KERNEL_DIR}"
echo "[fetch-base] 订阅方式查看版本: grep VERSION $KERNEL_DIR/Makefile 或 git -C $KERNEL_DIR log -1"