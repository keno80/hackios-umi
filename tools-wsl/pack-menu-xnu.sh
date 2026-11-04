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
CHK=$WS/out/umi/boot/pack-check.txt
python3 - "$IMG" "$FAT" "$DTB" "$FD" >"$CHK" <<'PY'
import hashlib, struct, sys, zlib
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
fat_b = open(fat, 'rb').read()
# 真实布局：header 一页 → kernel → second(整卷)。ramdisk 字段只是声明，不占字节。
second_off = page * (1 + -(-kernel_size // page))
ok = []
ok.append(('FD 尾段一致（%d B）' % len(fd_b), raw[-len(fd_b):] == fd_b))
ok.append(('FD sha == b4e1acc2…', hashlib.sha256(fd_b).hexdigest().startswith('b4e1acc2')))
shim = raw[:-len(fd_b)]
# ARM64 boot header：magic 在 shim+0x38，字节是 A R M 0x64
ok.append(('shim %d B，magic ARM\\x64 @0x38' % len(shim), shim[56:60] == b'ARM\x64'))
ok.append(('second 段 == 整卷 %d B @ %#x' % (len(fat_b), second_off),
           second_size == len(fat_b) and d[second_off:second_off+len(fat_b)] == fat_b))
ok.append(('镜像尾部正好收在卷末', second_off + len(fat_b) == len(d)))
ok.append(('卷内菜单带 rd=md0 与 initrd', b'rd=md0 ' in fat_b and b'initrd = "Payloads/launchd.macho"' in fat_b))
ok.append(('卷内有 launchd.macho 目录项', b'LAUNCH~1MAC' in fat_b.replace(b' ', b'')))
ok.append(('卷 sha %s' % hashlib.sha256(fat_b).hexdigest()[:8], True))
for label, good in ok:
    print('  %s%s' % ('OK  ' if good else 'FAIL', label))
print('RESULT', 'ALL-OK' if all(g for _, g in ok) else 'HAS-FAIL')
PY
cat "$CHK"

echo "== 3. 交付到 out/images/"
if grep -q 'RESULT ALL-OK' "$CHK"; then
  mkdir -p /mnt/e/Code/HackIos/out/images
  cp -f "$IMG" /mnt/e/Code/HackIos/out/images/umi-uefi-menu-xnu.img
  ls -l /mnt/e/Code/HackIos/out/images/umi-uefi-menu-xnu.img | sed 's#^# #'
  sha256sum /mnt/e/Code/HackIos/out/images/umi-uefi-menu-xnu.img | sed 's#^# #'
else
  echo "== 自检未过，不交付"
fi
echo "== done $(date -u +%FT%TZ)"
