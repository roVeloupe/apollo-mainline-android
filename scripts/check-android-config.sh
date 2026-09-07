#!/usr/bin/env bash
# check-android-config.sh <kernel Image>
# 从内核 Image 内嵌 config(CONFIG_IKCONFIG) 判定 Android 就绪度。
# 判定 M1 冒烟需要的关键符号。
set -euo pipefail

IMAGE="${1:?用法: check-android-config.sh <kernel Image>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[check] 从 $IMAGE 提取内嵌 config\n"
CFG="$("$SCRIPT_DIR/ikconfig_extract.py" "$IMAGE" 2>/dev/null || true)"
if [ -z "$CFG" ]; then
  echo "[check] 无内嵌 config（未开 CONFIG_IKCONFIG），无法自动判定 Android 就绪度。"
  echo "[check] 若这是官方 pmOS kernel，请改用其源码 defconfig 名再判。"
  exit 3
fi

declare -A MUST=( [CONFIG_ANDROID]=1 [CONFIG_ANDROID_BINDER_IPC]=1 [CONFIG_ANDROID_BINDERFS]=1 [CONFIG_DMABUF_HEAPS]=1 [CONFIG_PSI]=1 )
ok=1
for k in CONFIG_ANDROID CONFIG_ANDROID_BINDER_IPC CONFIG_ANDROID_BINDERFS CONFIG_DMABUF_HEAPS CONFIG_DMABUF_SYSTEM_HEAP CONFIG_DMABUF_HEAPS_CMA CONFIG_PSI; do
  v=$(echo "$CFG" | grep -E "^${k}=y$" | head -n1 || true)
  if [ -n "$v" ]; then
    echo "  [OK  ] $v"
  else
    echo "  [MISS] $k"
    [ "${MUST[$k]:-}" = 1 ] && ok=0
  fi
done

if [ "$ok" = 1 ]; then
  echo "[check] 汇总: 满足 Android 最小集，可直接用 assemble-bootimg.sh 重打 AOSP boot.img。"
else
  echo "[check] 汇总: 缺少必需 Android 符号(binder/dmabuf-heaps/PSI)。"
  echo "[check] 该内核无法直接宿主 AOSP；必须用 configs/android.fragment 合入后重新编译(见 build.sh)。"
fi