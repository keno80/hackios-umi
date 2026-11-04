#!/bin/bash
# run-06 进度摘要
L=/home/unixnu/code/umi-work-pin/out/umi-fw/run-06/firmware.log
O=/mnt/e/Code/HackIos/out/probes/fw06-status.txt
FD=/home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
{
if [ ! -f "$L" ]; then echo "日志还没生成"; tail -5 /home/unixnu/code/umi-work-pin/out/umi-fw/run-06.outer.log; exit 0; fi
echo "存活=$(pgrep -f 'uefi-fw-build run-06' | head -1) clang=$(pgrep -c clang) 日志=$(stat -c %s $L)B 改动=$(date -r $L '+%H:%M:%S')"
echo "Building=$(grep -c '^Building' $L) obj=$(find /home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/AARCH64 -name '*.obj' | wc -l) efi=$(find /home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/AARCH64 -maxdepth 1 -name '*.efi' | wc -l)"
echo "error=$(grep -c 'error:' $L)"
grep -E "error:|Error [0-9]|FAILED" $L | head -6 | cut -c1-260
awk 'length($0)<200' $L | tail -3
[ -f $FD ] && printf "== FD %s bytes sha256=%s\n" "$(stat -c %s $FD)" "$(sha256sum $FD | cut -d' ' -f1)"
} > $O 2>&1
echo WROTE
