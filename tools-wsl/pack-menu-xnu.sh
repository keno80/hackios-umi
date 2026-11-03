#!/bin/bash
# #19：用本机 8G 卷 + 源码内核打真机镜像（宿主机侧，不碰手机）
set -u
WS=/home/unixnu/code/umi-work-pin
UEFI=/home/unixnu/code/uefi-umi-b
LOG=$WS/out/umi-fw/pack-xnu.log
exec > "$LOG" 2>&1
cd "$WS" || exit 1

DTB=$WS/out/umi/dtb/umi-running.dtb
FAT=$WS/out/umi/xnu/umi-xnu-fat.img
FD=$UEFI/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd

export PATH=/usr/local/bin:/usr/bin:/bin
export UNIXNU_DTB="$DTB"

echo "== 0. 输入"
ls -la "$FAT" "$DTB" "$FD"
sha256sum "$FAT" "$DTB" "$FD"
ls -la out/umi/xnu/stage2/EFI/UniXNU/Payloads/

echo "== 1. bootimg（--ramdisk 挂 XNU 卷）"
python3 sources/UniXNU/unixnu bootimg \
  -D devices/umi --out out/unixnu --uefi "$UEFI" --target DEBUG \
  --dtb "$DTB" --ramdisk "$FAT" \
  -o out/umi/boot/umi-uefi-menu-xnu.img
echo "== bootimg rc=$?"

IMG=$WS/out/umi/boot/umi-uefi-menu-xnu.img
ls -la "$IMG" 2>/dev/null; sha256sum "$IMG" 2>/dev/null

echo "== 2. 拆包自检"
python3 - "$IMG" "$FAT" "$DTB" "$FD" <<'PY'
import gzip, hashlib, struct, sys, zlib
img, fat, dtb, fd = sys.argv[1:5]
d = open(img, 'rb').read()
kernel_size, ramdisk_size, second_size = struct.unpack_from('<3I', d, 8)
page = struct.unpack_from('<I', d, 36)[0]
hdr_ver = struct.unpack_from('<I', d, 48)[0]
print('magic', d[:8], 'page', page, 'header_version', hdr_ver)
print('kernel %d  ramdisk %d  second %d  image %d' % (kernel_size, ramdisk_size, second_size, len(d)))
kg = d[page:page+kernel_size]
raw = zlib.decompressobj(16+zlib.MAX_WBITS).decompress(kg)
fd_b = open(fd, 'rb').read()
tree = open(dtb, 'rb').read()
fat_b = open(fat, 'rb').read()
ok = []
ok.append(('FD 尾段一致（3,145,728 B）', raw[-len(fd_b):] == fd_b))
ok.append(('FD sha == b4e1acc2…', hashlib.sha256(fd_b).hexdigest().startswith('b4e1acc2')))
ok.append(('内嵌 DTB 尾 == running.dtb', raw.endswith(tree)))
shim = raw[:-len(fd_b)]
ok.append(('shim %d B，magic ARM64' % len(shim), shim[56:60] == b'ARM6'))
rb = d[2*page:2*page+ramdisk_size]
ok.append(('ramdisk 段 == 整卷 %d B' % len(fat_b), rb[:len(fat_b)] == fat_b))
ok.append(('卷 sha %s' % hashlib.sha256(fat_b).hexdigest()[:8], True))
hdr = struct.unpack_from('<4I', d, 16)
ok.append(('载荷地址 base=%x kload=%x tags=%d(=%x)' % (hdr[0], hdr[1], hdr[3], hdr[3]), True))
for label, good in ok:
    print('  %s%s' % ('OK  ' if good else 'FAIL', label))
print('RESULT', 'ALL-OK' if all(g for _, g in ok) else 'HAS-FAIL')
PY
echo "== done $(date -u +%FT%TZ)"
