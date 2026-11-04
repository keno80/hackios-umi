#!/bin/bash
S=/home/unixnu/code/umi-work-pin/devices/umi/overlay/Platforms/Xiaomi/umiPkg
echo "===== UmiMemoryDiag.inf"; cat "$S/Application/UmiMemoryDiag/UmiMemoryDiag.inf" 2>/dev/null || echo "(不在 overlay)"
echo "===== UmiMemoryDiag.c ($(wc -l < "$S/Application/UmiMemoryDiag/UmiMemoryDiag.c" 2>/dev/null) 行)"
cat "$S/Application/UmiMemoryDiag/UmiMemoryDiag.c" 2>/dev/null
echo "===== UmiRamPayloadDxe 位置"
find /home/unixnu/code/uefi-umi-b/Platforms/Xiaomi/umiPkg/Drivers/UmiRamPayloadDxe -type f 2>/dev/null | sed 's#^#  #'
echo "===== run-07 进度"
L=/home/unixnu/code/umi-work-pin/out/umi-fw/run-07/firmware.log
echo "  行数=$(wc -l < "$L" 2>/dev/null)  build 计数=$(grep -c 'Building target' "$L" 2>/dev/null)"
tail -6 "$L" 2>/dev/null | sed 's#^#  | #'
