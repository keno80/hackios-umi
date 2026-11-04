#!/bin/bash
OUT=/mnt/e/Code/HackIos/out/probes/menu-bootjson.txt
: > "$OUT"
WS=/home/unixnu/code/umi-work-pin
echo "== boot.json（打包自校验报告）" >> "$OUT"
cat "$WS/out/umi/boot/boot.json" >> "$OUT" 2>&1
echo "== 镜像字节布局实测" >> "$OUT"
python3 - "$WS/out/umi/boot/umi-uefi-menu.img" <<'PY' >> "$OUT" 2>&1
import sys, struct, gzip, hashlib
d = open(sys.argv[1], 'rb').read()
ks, rs, ss = struct.unpack_from('<3I', d, 8)
tags, page = struct.unpack_from('<2I', d, 32)
ver = struct.unpack_from('<I', d, 40)[0]
dtb_size = struct.unpack_from('<I', d, 44)[0]
cmdline = d[48:48+24].split(b'\0')[0].decode()
print('kernel %d ramdisk %d second %d page %d ver %d dtb_size %d' % (ks, rs, ss, page, ver, dtb_size))
print('cmdline:', cmdline)
for label, needle in (('gzip', b'\x1f\x8b\x08'), ('FDT', b'\xd0\x0d\xfe\xed')):
    print(label, 'first at', hex(d.find(needle)))
fd = open('/home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd','rb').read()
print('FD sha', hashlib.sha256(fd).hexdigest())
# 按 boot.json 的 offset 语义，直接从 gzip 头解
g = d.find(b'\x1f\x8b\x08')
raw = gzip.decompress(d[g:])
print('gunzip ->', len(raw), 'tail==FD:', raw[-len(fd):] == fd, 'shim bytes', len(raw)-len(fd))
PY
echo "== board.toml 里 bootimg 段（dtb_node 有没有）" >> "$OUT"
grep -nA 8 -E "^\[bootimg" "$WS/devices/umi/board.toml" >> "$OUT" 2>&1
echo "== 拷贝到 Windows 侧" >> "$OUT"
cp -f "$WS/out/umi/boot/umi-uefi-menu.img" /mnt/e/Code/HackIos/out/images/umi-uefi-menu.img && sha256sum /mnt/e/Code/HackIos/out/images/umi-uefi-menu.img >> "$OUT" 2>&1
echo "== fastboot 版本（Windows 侧另跑）" >> "$OUT"
echo "WROTE"
