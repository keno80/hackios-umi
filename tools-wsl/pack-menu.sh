#!/bin/bash
# 打 umi-uefi-menu.img（宿主机侧，不碰手机）
set -u
WS=/home/unixnu/code/umi-work-pin
UEFI=/home/unixnu/code/uefi-umi-b
LOG=$WS/out/umi-fw/pack-menu.log
exec > "$LOG" 2>&1
cd "$WS" || exit 1

DTB_SRC=/mnt/e/Code/HackIos/out/phone3/running.dtb
DTB=$WS/out/umi/dtb/umi-running.dtb
mkdir -p "$WS/out/umi/dtb" "$WS/out/umi/boot"
cp -f "$DTB_SRC" "$DTB" || { echo "COPY FAIL"; exit 1; }

export PATH=/usr/local/bin:/usr/bin:/bin
export UNIXNU_DTB="$DTB"

echo "== bootimg pack start $(date -u +%FT%TZ)"
python3 sources/UniXNU/unixnu bootimg \
  -D devices/umi --out out/unixnu --uefi "$UEFI" --target DEBUG \
  --dtb "$DTB" --ramdisk none \
  -o out/umi/boot/umi-uefi-menu.img
RC=$?
echo "== bootimg rc=$RC"

IMG=$WS/out/umi/boot/umi-uefi-menu.img
if [ $RC -eq 0 ] && [ -f "$IMG" ]; then
  echo "== image"
  ls -la "$IMG"
  sha256sum "$IMG"
  echo "== 自校验：拆包比对 FD"
  python3 - "$IMG" <<'PY'
import gzip, hashlib, struct, sys
p = sys.argv[1]
d = open(p, 'rb').read()
magic = d[:8]
kernel_size, ramdisk_size, second_size = struct.unpack_from('<3I', d, 8)
page, hdr_ver, _, _ = struct.unpack_from('<4I', d, 36)
print('magic', magic, 'page', page, 'header_version', hdr_ver)
print('kernel %d  ramdisk %d  second %d' % (kernel_size, ramdisk_size, second_size))
kg = d[page:page + kernel_size]
raw = gzip.decompress(kg)
print('gunzipped kernel blob: %d' % len(raw))
fd = open('/home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd', 'rb').read()
print('FD bytes %d sha %s' % (len(fd), hashlib.sha256(fd).hexdigest()))
tail = raw[-len(fd):]
print('FD tail match:', hashlib.sha256(tail).hexdigest() == hashlib.sha256(fd).hexdigest())
shim = raw[:-len(fd)]
print('shim bytes %d  ARM64hdr %s' % (len(shim), shim[56:60]))
text_end, image_size = struct.unpack_from('<2Q', shim, 8)
print('shim header text_end=%#x image_size=%#x (expect image_size=%#x)' % (text_end, image_size, len(raw)))
PY
fi
echo "== done $(date -u +%FT%TZ)"
