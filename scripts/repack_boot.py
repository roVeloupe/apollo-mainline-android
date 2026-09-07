#!/usr/bin/env python3
"""按 boot.img 真实参数重封装 AOSP boot (header v2) : kernel(主镜像6.11) + ramdisk + dtb"""
import math, sys, struct
sps=4096
def pages(n): return math.ceil(n/sps)

# 真实参数(来自用户boot.img解包)
VER=2; OS_VER=0x200001a8
CMD="androidboot.hardware=qcom androidboot.console=ttyMSM0 androidboot.memcg=1 lpm_levels.sleep_disabled=1 msm_rtb.filter=0x237 service_locator.enable=1 androidboot.usbcontroller=a600000.dwc3 swiotlb=2048 loop.max_part=7 cgroup.memory=nokmem,nosocket reboot=panic_warm androidboot.fstab_suffix=qcom androidboot.init_fatal_reboot_target=recovery"

kernel_path=sys.argv[1]; ramdisk_path=sys.argv[2]; dtb_path=sys.argv[3]; out=sys.argv[4]
K=open(kernel_path,'rb').read(); R=open(ramdisk_path,'rb').read(); D=open(dtb_path,'rb').read()

HEADER_SIZE=1660
MAGIC=b'ANDROID!'
hdr=bytearray(HEADER_SIZE)
def w32(o,v): hdr[o:o+4]=struct.pack('<I',v)
def w64(o,v): hdr[o:o+8]=struct.pack('<Q',v)
hdr[0:8]=MAGIC
w32(0x08,len(K));    w32(0x0c,0x00008000)   # kernel_addr
w32(0x10,len(R));    w32(0x14,0x01000000)   # ramdisk_addr
w32(0x18,0);         w32(0x1c,0)            # second
w32(0x20,0x00010000)                        # tags_addr
w32(0x24,sps)                               # page_size
w32(0x28,VER)                               # header_version
w32(0x2c,OS_VER)                            # os_version
hdr[0x30:0x30+len(CMD)]=CMD.encode()        # name/cmdline share? name[16] then cmdline[512]; 在0x40
# name[16] @0x30, cmdline[512] @0x40
hdr[0x40:0x40+512]=b'\x00'*512
hdr[0x40:0x40+len(CMD)]=CMD.encode()
# v1/v2 尾
w32(0x660,0)          # recovery_dtbo_size
w64(0x664,0)          # recovery_dtbo_offset
w32(0x66c,HEADER_SIZE)
w32(0x670,len(D))     # dtb_size
w64(0x674,0x1f00000)  # dtb_addr

# 布局
koff=sps
roff=koff+pages(len(K))*sps
doff=roff+pages(len(R))*sps
end=doff+pages(len(D))*sps
buf=bytearray(end)
buf[0:HEADER_SIZE]=hdr
buf[koff:koff+len(K)]=K
buf[roff:roff+len(R)]=R
buf[doff:doff+len(D)]=D
open(out,'wb').write(buf)
print(f"完成: {out}")
print(f"  kernel {len(K)}B @{koff}, ramdisk {len(R)}B @{roff}, dtb {len(D)}B @{doff}, total {end}B")