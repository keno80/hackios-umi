#!/bin/bash
# G 步：把仓库里的 UmiBootLog 装进固件工作树，增量重编（只动这个 App，FD 不该变）
set -u
OUT=/mnt/e/Code/HackIos/out/probes/g-bootlog-build.txt
: > "$OUT"
exec >>"$OUT" 2>&1
SRC=/mnt/e/Code/HackIos/devices/umi/fw/UmiBootLog
DST=/home/unixnu/code/uefi-umi-b/Platforms/Xiaomi/umiPkg/Application/UmiBootLog
echo "== 1. 安装 =="
cp "$SRC/UmiBootLog.c" "$DST/UmiBootLog.c" && cp "$SRC/UmiBootLog.inf" "$DST/UmiBootLog.inf"
echo "installed rc=$?"
md5sum "$SRC/UmiBootLog.c" "$DST/UmiBootLog.c"
echo
echo "== 2. 增量构建 =="
bash /mnt/e/Code/HackIos/tools-wsl/build-umi-fd.sh run-g
echo "build rc=$?"
echo
echo "== 3. 产物 =="
E=/home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/AARCH64/umiPkg/Application/UmiBootLog/UmiBootLog/OUTPUT/UmiBootLog.efi
ls -la "$E"
sha256sum "$E"
echo "FD:"
ls -la /home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
sha256sum /home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
echo "DONE"
