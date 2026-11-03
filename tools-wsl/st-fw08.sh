#!/bin/bash
W=/home/unixnu/code/umi-work-pin
O=$W/out/umi-fw/run-08.outer.log
L=$W/out/umi-fw/run-08/firmware.log
echo "  进程=$(pgrep -f uefi-fw-build >/dev/null && echo 运行中 || echo 已结束)"
echo "  outer 行数=$(wc -l < "$O")  firmware 行数=$(wc -l < "$L")"
echo "--- 结论行 ---"
grep -n -E "error|Done|build rc|FAILED|Building target" "$O" | cut -c1-160 | tail -14
echo "--- outer 尾部 ---"
tail -6 "$O" | cut -c1-160 | sed 's#^#  | #'
echo "--- 本次模块痕迹 ---"
grep -o -E "UmiMemoryDiag|RamProbe|MemOut" "$L" | sort | uniq -c | sed 's#^#  #'
echo "--- FD ---"
ls -l "$W/../code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd" 2>/dev/null | sed 's#^#  #'
