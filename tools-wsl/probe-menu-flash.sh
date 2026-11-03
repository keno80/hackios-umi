#!/bin/bash
# #10 前置 3：FD 窗口是否被 System RAM 占 + 这镜像到底怎么上机（有没有免写的 fastboot boot 路径）
P3=/mnt/e/Code/HackIos/out/phone3
WS=/home/unixnu/code/umi-work-pin
{
echo "== iomem 里 0x9f/0xa0 段"
grep -inE "^ *(9f|a0)[0-9a-f]{6}" $P3/iomem.txt | head -20
echo "== System RAM 全部段（判断 0x9fc00000 落点）"
grep -i "System RAM" $P3/iomem.txt | head -12
echo "== reserved-memory 里挨着 FD 窗口的节点"
grep -nE "9fc00000|9e[0-9a-f]{6}|9f[0-9a-f]{6}|a0000000|a1[0-9a-f]{6}" $P3/dt/running.dts | head -20

echo "== 上机方式：有没有 fastboot boot / imagefv / 分区名"
grep -rIn "fastboot boot\|fastboot flash\|imagefv\|umi-uefi-menu" $WS/sources/UniXNU $WS/devices/umi $WS/tools 2>/dev/null | grep -v '\.pyc' | head -20
echo "== 设备仓 README/Status 里的菜单上机说明"
grep -rIn -A3 -B1 "menu.img\|uefi-menu" $WS/sources/uefi-umi/README*.md $WS/sources/uefi-umi/Building.md $WS/sources/uefi-umi/Status.md 2>/dev/null | head -30
echo "== UniXNU 文档里 bootimg 的用法"
grep -rIn "bootimg" $WS/sources/UniXNU/scripts/unixnu/*.py | head -12
} > /mnt/e/Code/HackIos/out/menu-flash.txt 2>&1
echo WROTE
