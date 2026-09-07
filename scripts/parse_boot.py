#!/usr/bin/env python3
"""解析 Android boot img (支持 header v0/v1/v2) 并抽取 kernel/ramdisk/dtb + 打印打包参数"""
import sys, struct, math

path = sys.argv[1]
outdir = sys.argv[2] if len(sys.argv)>2 else '.'
d = open(path,'rb').read()
MAGIC = b'ANDROID!'
assert d[:8]==MAGIC, "不是 boot image"

kernel_size,u = struct.unpack_from('<I',d,0x08),0x0C
kernel_addr = struct.unpack_from('<I',d,u78)[0] if False else None
import os

def r32(o): return struct.unpack_from('<I',d,o)[0]
def r64(o): return struct.unpack_from('<Q',d,o)[0]
def cs(o,n): 
    s=d[o:o+n]; return s.split(b'\x00')[0].decode('latin1')

kernel_size  = r32(0x08); kernel_addr = r32(0x0C)
ramdisk_size = r32(0x10); ramdisk_addr= r32(0x14)
second_size  = r32(0x18); second_addr = r32(0x1C)
tags_addr    = r32(0x20)
page_size    = r32(0x24)
header_ver   = r32(0x28)
os_ver       = r32(0x2C)
name         = cs(0x30,16)
cmdline      = cs(0x40,512) 

print(f"header_version={header_ver}")
print(f"page_size={page_size}")
print(f"kernel_size={kernel_size} addr=0x{kernel_addr:x}")
print(f"ramdisk_size={ramdisk_size} addr=0x{ramdisk_addr:x}")
print(f"second_size={second_size} addr=0x{second_addr:x}")
print(f"tags_addr=0x{tags_addr:x}")
print(f"name='{name}'")
print(f"os_version=0x{os_ver:x}")
print(f"cmdline={cmdline}")

# extra_cmdline (v1+), recovery_dtbo, header_size, dtb (v2)
extra_cmdline=""
recovery_dtbo_size=recovery_dtbo_offset=header_size=0
dtb_size=dtb_addr=0
if header_ver>=1:
    # id[32] @0x240, extra_cmdline[1024] @0x260
    extra_cmdline = cs(0x260,1024)
    print(f"extra_cmdline={extra_cmdline}")
    recovery_dtbo_size=r32(0x660)
    recovery_dtbo_offset=r64(0x668)
    header_size=r32(0x670)
    print(f"recovery_dtbo_size={recovery_dtbo_size} offset={recovery_dtbo_offset}")
    print(f"header_size={header_size}")
    if header_ver>=2:
        dtb_size=r32(0x674)
        dtb_addr=r64(0x678)
        print(f"dtb_size={dtb_size} addr=0x{dtb_addr:x}")
# v0 uses id[32] only, v1/v2 no id at 0x240 (it's extra_cmdline region); ignore

print(f"file_size={len(d)}  header_size_reported={header_size}")

# 计算布局 (v2: kernel, ramdisk, second, recovery_dtbo, dtb 顺序)
def pages(n): return (n+page_size-1)//page_size
off = header_size if header_ver>=1 else 1632
if header_ver>=1:
    off = r32(0x670)  # header_size
else:
    off = 1632
seg=[]
ker_off=off; ker_pg=pages(kernel_size); off+=ker_pg*page_size
ram_off=off; ram_pg=pages(ramdisk_size); off+=ram_pg*page_size
if second_size: off+=pages(second_size)*page_size
rec_off=0
if header_ver>=2 and recovery_dtbo_size:
    rec_off=off; off+=pages(recovery_dtbo_size)*page_size
dtb_off=0
if header_ver>=2 and dtb_size:
    dtb_off=off; off+=pages(dtb_size)*page_size
print(f"kernel_off={ker_off} ramdisk_off={ram_off} recovery_dtbo_off={rec_off} dtb_off={dtb_off} end={off}")

# 抽取
open(f"{outdir}/kernel.bin","wb").write(d[ker_off:ker_off+kernel_size])
if ramdisk_size: open(f"{outdir}/ramdisk.bin","wb").write(d[ram_off:ram_off+ramdisk_size])
if recovery_dtbo_size: open(f"{outdir}/recovery_dtbo.bin","wb").write(d[rec_off:rec_off+recovery_dtbo_size])
if dtb_size: open(f"{outdir}/dtb.bin","wb").write(d[dtb_off:dtb_off+dtb_size])
print("extracted: kernel.bin, ramdisk.bin, dtb(s)")
# ramdisk magic
print("ramdisk首4字节:", d[ram_off:ram_off+4].hex())