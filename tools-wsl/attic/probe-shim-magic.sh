#!/bin/bash
# 探 shim 头：确认 ARM64 magic 的真实字节与偏移
set -u
WS=/home/unixnu/code/umi-work-pin
UEFI=/home/unixnu/code/uefi-umi-b
OUT=/mnt/e/Code/HackIos/out/probes/probe-shim.txt
exec > "$OUT" 2>&1
python3 - "$WS/out/umi/boot/umi-uefi-menu-xnu.img" "$UEFI/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd" <<'PY'
import struct, sys, zlib
img, fd = sys.argv[1:3]
d = open(img, 'rb').read()
kernel_size = struct.unpack_from('<I', d, 8)[0]
page = struct.unpack_from('<I', d, 36)[0]
raw = zlib.decompressobj(16 + zlib.MAX_WBITS).decompress(d[page:page + kernel_size])
fd_b = open(fd, 'rb').read()
shim = raw[:-len(fd_b)]
print('raw %d  fd %d  shim %d' % (len(raw), len(fd_b), len(shim)))
print('shim[:64] hex:', shim[:64].hex())
for off in range(0, 64, 4):
    print('  %#04x %s' % (off, shim[off:off + 4]))
for needle in (b'ARM', b'ARM\x64', b'ARM64', b'MM64', b'\x16\x00\x00\x9a'):
    print('find %r -> %d' % (needle, shim.find(needle)))
print('shim[0x20:0x40] %r' % shim[0x20:0x40])
PY
