#!/usr/bin/env python3
# ikconfig_extract.py
# 从 Linux 内核 Image 提取内嵌 .config（CONFIG_IKCONFIG）。若无内嵌则报错退出 1。
# 用法: ikconfig_extract.py <kernel Image>   （config 输出到 stdout）
import sys, lzma, bz2, gzip, zlib

def main():
    if len(sys.argv) != 2:
        print("usage: extract_ikconfig <kernel Image>", file=sys.stderr)
        sys.exit(2)
    data = open(sys.argv[1], 'rb').read()
    ST, ED = b'IKCFG_ST', b'IKCFG_ED'
    i = data.find(ST)
    if i < 0:
        print("IKCFG_ST 未找到（该内核未开 CONFIG_IKCONFIG）", file=sys.stderr)
        sys.exit(1)
    j = data.find(ED, i + len(ST))
    if j < 0:
        print("IKCFG_ED 未找到", file=sys.stderr)
        sys.exit(1)
    blob = data[i + len(ST):j]
    for name, dec in (
        ('xz', lzma.decompress),
        ('bzip2', bz2.decompress),
        ('gzip', gzip.decompress),
        ('zlib32', lambda b: zlib.decompress(b, zlib.MAX_WBITS | 32)),
    ):
        try:
            cfg = dec(blob)
            print(f"[ikconfig] 解压算法: {name}", file=sys.stderr)
            sys.stdout.buffer.write(cfg)
            sys.exit(0)
        except Exception:
            pass
    print("无法解压 IKCFG", file=sys.stderr)
    sys.exit(1)

if __name__ == '__main__':
    main()