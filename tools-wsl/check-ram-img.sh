#!/bin/bash
W=/home/unixnu/code/umi-work-pin
IMG=$W/out/umi/boot/umi-uefi-menu-ram.img
FAT=$W/out/umi/payload/umi-ram-fat.img
DTB=/mnt/e/Code/HackIos/out/phone3/running.dtb
python3 - "$IMG" "$FAT" "$DTB" <<'PY'
import hashlib, struct, sys, zlib
img, fat, dtb = sys.argv[1:4]
d = open(img, 'rb').read()
kernel_size, kernel_addr = struct.unpack_from('<2I', d, 8)
ramdisk_size, ramdisk_addr = struct.unpack_from('<2I', d, 16)
second_size, second_addr, tags_addr, page = struct.unpack_from('<4I', d, 24)
hdr_ver = struct.unpack_from('<I', d, 40)[0]
cmdline = d[64:576].split(b'\0')[0].decode('ascii', 'replace')
print(f'magic={d[:8]} page={page} header_version={hdr_ver}')
print(f'kernel  size={kernel_size:<8} addr=0x{kernel_addr:x}')
print(f'ramdisk size={ramdisk_size:<8} addr=0x{ramdisk_addr:x}')
print(f'second  size={second_size} tags=0x{tags_addr:x}')
print(f'cmdline={cmdline[:120]}')

start = page
blob = d[start:start + kernel_size]
dec = zlib.decompressobj(16 + zlib.MAX_WBITS)
raw = dec.decompress(blob)
tree = dec.unused_data
print(f'gunzip: shim+FD={len(raw)} 尾部 DTB={len(tree)}  '
      f'DTB==running.dtb {tree == open(dtb,"rb").read()}')
fd = open('/home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd','rb').read()
print(f'FD 匹配: {raw[-len(fd):] == fd}  shim={len(raw)-len(fd)}B 头={raw[56:60]}')

rstart = page * (1 + -(-kernel_size // page))
rb = d[rstart:rstart + ramdisk_size]
fatb = open(fat, 'rb').read()
print(f'ramdisk 段 @0x{rstart:x} len={len(rb)}  ==FAT: {rb == fatb}  '
      f'sha={hashlib.sha256(rb).hexdigest()[:16]}')
print(f'FAT bootsec: bps={struct.unpack_from("<H", rb, 11)[0]} '
      f'sectors={struct.unpack_from("<H", rb, 19)[0] or struct.unpack_from("<I", rb, 32)[0]} '
      f'sig=0x{rb[510]:02x}{rb[511]:02x}  容量={len(rb)/2**20:.1f} MiB')
print('镜像 sha256:', hashlib.sha256(d).hexdigest())
print('镜像字节:', len(d))
PY
echo "== 拷到 Windows 侧"
cp -f "$IMG" /mnt/e/Code/HackIos/out/umi-uefi-menu-ram.img && ls -l /mnt/e/Code/HackIos/out/umi-uefi-menu-ram.img | sed 's#^#  #'
sha256sum /mnt/e/Code/HackIos/out/umi-uefi-menu-ram.img | sed 's#^#  #'
