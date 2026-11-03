#!/bin/bash
S=/home/unixnu/code/umi-work-pin/devices/umi/overlay/Platforms/Xiaomi/umiPkg
echo "== UmiMemoryDiag.c 120-187"
sed -n '120,187p' "$S/Application/UmiMemoryDiag/UmiMemoryDiag.c"
echo "== 是否用 Print/AsciiPrint（屏幕可见）"
grep -c -E "Print\(|AsciiPrint|UnicodePrint|gST->ConOut" "$S/Application/UmiMemoryDiag/UmiMemoryDiag.c"
echo "== RamProbe.c 里的输出方式"
grep -n -E "Print\(|AsciiPrint|DEBUG \(" "$S/Application/UmiMemoryDiag/RamProbe.c" 2>/dev/null | head -20
echo "== run-07 进度"
L=/home/unixnu/code/umi-work-pin/out/umi-fw/run-07/firmware.log
echo "  行数=$(wc -l < "$L" 2>/dev/null)"
grep -n -E "error|Error|FAILED|build.py|Generating image|done" "$L" 2>/dev/null | tail -10 | sed 's#^#  #'
tail -4 "$L" 2>/dev/null | sed 's#^#  | #'
