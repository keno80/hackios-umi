#!/bin/bash
# 核对新 UmiBootLog.efi，并把上次上机验证过的 FD 从已打好的镜像里还原回 Build 目录
set -u
OUT=/mnt/e/Code/HackIos/out/g-fd-restore.txt
: > "$OUT"
exec >>"$OUT" 2>&1
UEFI=/home/unixnu/code/uefi-umi-b
E=$UEFI/Build/umiPkg/DEBUG_CLANGPDB/AARCH64/umiPkg/Application/UmiBootLog/UmiBootLog/OUTPUT/UmiBootLog.efi
FD=$UEFI/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
IMG=/home/unixnu/code/umi-work-pin/out/umi/boot/umi-uefi-menu-xnu.img
echo "== 1. 新 UmiBootLog.efi =="
ls -la "$E"; sha256sum "$E"
echo "含 UMI XNU 针 = $(strings -a "$E" | grep -c 'UMI XNU')"
echo "含 markers 段名 = $(strings -a "$E" | grep -c 'markers')"
echo
echo "== 2. 当前 FD（被本次重建覆盖）=="
ls -la "$FD"; sha256sum "$FD"
echo
echo "== 3. 从上次上机镜像里抽 FD =="
ls -la "$IMG"; sha256sum "$IMG"
python3 - "$IMG" "$FD" <<'PY'
import hashlib, struct, sys, zlib
img, fdpath = sys.argv[1:3]
d = open(img, 'rb').read()
kernel_size = struct.unpack_from('<I', d, 8)[0]
page = struct.unpack_from('<I', d, 36)[0]
kg = d[page:page+kernel_size]
raw = zlib.decompressobj(16+zlib.MAX_WBITS).decompress(kg)
old = open(fdpath, 'rb').read()
cand = raw[-len(old):]
print('extracted bytes', len(cand), 'sha256', hashlib.sha256(cand).hexdigest())
print('on-disk   bytes', len(old), 'sha256', hashlib.sha256(old).hexdigest())
if hashlib.sha256(cand).hexdigest().startswith('b4e1acc2'):
    open(fdpath, 'wb').write(cand)
    print('RESTORED ->', hashlib.sha256(open(fdpath,'rb').read()).hexdigest())
else:
    print('REFUSE: 抽出来的 FD 不是预期的 b4e1acc2…')
PY
echo "DONE"
