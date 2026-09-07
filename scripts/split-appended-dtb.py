#!/usr/bin/env python3
# split-appended-dtb.py <kernel Image> [outdir]
# 从 "Image 尾部追加的 DTB"(pmOS/append_dtb 风格) 里按 FDT 魔数切出候选 dtb。
# 用法: 主要选 label 含 qcom/sm8250-xiaomi-apollo 的那份作为 --dtb。
import sys, os

def main():
    if len(sys.argv) < 2 or len(sys.argv) > 3:
        print("usage: split-appended-dtb.py <kernel Image> [outdir]", file=sys.stderr)
        sys.exit(2)
    src = sys.argv[1]
    outdir = sys.argv[2] if len(sys.argv) == 3 else "dtbs_out"
    os.makedirs(outdir, exist_ok=True)
    data = open(src, 'rb').read()
    magic = b'\xd0\x0d\xfe\xed'  # FDT_MAGIC, big-endian
    idx, found = 0, 0
    while True:
        i = data.find(magic, idx)
        if i < 0:
            break
        found += 1
        size = int.from_bytes(data[i+4:i+8], 'big')  # totalsize (be)
        blob = data[i:i+size] if i+size <= len(data) else data[i:]
        p = os.path.join(outdir, f"dtb_candidate_{found:02d}_off{i:x}.dtb")
        open(p, 'wb').write(blob)
        print(f"  [{found}] FDT @0x{i:x} totalsize~0x{size:x} -> {p}")
        idx = i + size
    if not found:
        print("未找到嵌入 FDT(d0 0d fe ed)；可能 dtb 在 second 段或独立 dtbo/dtb 分区", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()