#!/bin/bash
# #16：重建内存诊断 FAT + 打 ram 档镜像（宿主机侧，不碰手机）
set -u
WS=/home/unixnu/code/umi-work-pin
UEFI=/home/unixnu/code/uefi-umi-b
LOG=$WS/out/umi-fw/pack-ram.log
exec > "$LOG" 2>&1
cd "$WS" || exit 1

DTB_SRC=/mnt/e/Code/HackIos/out/phone3/running.dtb
DTB=$WS/out/umi/dtb/umi-running.dtb
FAT=$WS/out/umi/payload/umi-ram-fat.img
mkdir -p "$WS/out/umi/dtb" "$WS/out/umi/boot"
cp -f "$DTB_SRC" "$DTB" || { echo "COPY FAIL"; exit 1; }

export PATH=/usr/local/bin:/usr/bin:/bin
export UNIXNU_DTB="$DTB"

echo "== 1. 重建 FAT（用新编的 UmiMemoryDiag.efi）"
python3 tools/make_umi_payload.py --diagnostic memory | tail -18
echo "  efi mtime: $(ls -l "$UEFI/Build/umiPkg/DEBUG_CLANGPDB/AARCH64/umiPkg/Application/UmiMemoryDiag/UmiMemoryDiag/OUTPUT/UmiMemoryDiag.efi" | awk '{print $6,$7,$8,$9}') $(sha256sum "$UEFI/Build/umiPkg/DEBUG_CLANGPDB/AARCH64/umiPkg/Application/UmiMemoryDiag/UmiMemoryDiag/OUTPUT/UmiMemoryDiag.efi" | cut -c1-16)"

echo "== 2. bootimg（--ramdisk 挂 FAT）"
python3 sources/UniXNU/unixnu bootimg \
  -D devices/umi --out out/unixnu --uefi "$UEFI" --target DEBUG \
  --dtb "$DTB" --ramdisk "$FAT" \
  -o out/umi/boot/umi-uefi-menu-ram.img
echo "== bootimg rc=$?"

IMG=$WS/out/umi/boot/umi-uefi-menu-ram.img
ls -la "$IMG" 2>/dev/null; sha256sum "$IMG" 2>/dev/null
cat out/umi/boot/boot.json 2>/dev/null | head -30

echo "== 3. 拆包自检"
python3 - "$IMG" "$FAT" "$DTB" <<'PY'
import gzip, hashlib, struct, sys, zlib
img, fat, dtb = sys.argv[1], sys.argv[2], sys.argv[3]
d = open(img, 'rb').read()
kernel_size, ramdisk_size, second_size = struct.unpack_from('<3I', d, 8)
page = struct.unpack_from('<I', d, 36)[0]
hdr_ver = struct.unpack_from('<I', d, 48)[0]
print('magic', d[:8], 'page', page, 'header_version', hdr_ver)
print('kernel %d  ramdisk %d  second %d' % (kernel_size, ramdisk_size, second_size))
kg = d[page:page+kernel_size]
raw = zlib.decompressobj(16+zlib.MAX_WBITS).decompress(kg)
fd = open('/home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd','rb').read()
tree = open(dtb,'rb').read()
print('inflated %d  FD tail match %s' % (len(raw), raw[-len(fd):] == fd))
print('shim %d bytes  ARM64 %s  DTB in image %s' % (len(raw)-len(fd), (raw[:-len(fd)])[56:60], raw.endswith(tree)))
fatb = open(fat,'rb').read()
rb = d[2*page:2*page+ramdisk_size]
print('ramdisk seg %d bytes  == FAT 前段 %s  (FAT %d)' % (len(rb), rb[:len(fatb)] == fatb, len(fatb)))
PY
echo "== done $(date -u +%FT%TZ)"
