#!/bin/bash
# #10 前置摸底（只读）：umi-uefi-menu.img 怎么打、刷哪儿、内存窗口/payload 常量在哪
WS=/home/unixnu/code/umi-work-pin
{
echo "== 谁提到 umi-uefi-menu.img"
grep -rIl "umi-uefi-menu" $WS/devices $WS/tools $WS/sources/UniXNU 2>/dev/null | head -20

echo "== 相关脚本清单"
find $WS/devices/umi -iname '*menu*' -o -iname '*uefi*' | grep -v '\.git' | head -30

echo "== fastboot/刷写动作在哪"
grep -rIn "fastboot flash\|fastboot --disable-verity\|dd if=" $WS/devices/umi $WS/tools 2>/dev/null | head -20

echo "== payload / owned_memory 常量出处"
grep -rIn "owned_memory\|OWNED_MEMORY\|payload_bytes\|0x130000000\|124" $WS/devices/umi/configs $WS/tools/umi_historical_receipts.py 2>/dev/null | head -20

echo "== FD_BASE 0x9fc00000 在哪些地方出现"
grep -rIn "9fc00000\|FD_BASE" $WS/devices/umi $WS/sources/UniXNU/scripts 2>/dev/null | head -20
} > /mnt/e/Code/HackIos/out/menu-img.txt 2>&1
echo WROTE
