#!/bin/bash
# 磁盘余量 + 是否残留 tmp；然后重跑 #8 为 run-06
{
echo "== df"
df -h /home/unixnu /mnt/e | tail -3
echo "== Fat OUTPUT 目录里的 Info 相关"
ls -l /home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/AARCH64/FatPkg/EnhancedFatDxe/Fat/OUTPUT/ | grep -i info | head
echo "== GNUmakefile 里 Info.obj 规则是否出现两种拼写"
GM=/home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/AARCH64/FatPkg/EnhancedFatDxe/Fat/GNUmakefile
grep -c "OUTPUT/./Info.obj" $GM 2>/dev/null; grep -c "OUTPUT/Info.obj" $GM 2>/dev/null
echo "== data-store 目录（packed APFS seed 的造/取处）"
ls /home/unixnu/code/umi-work-pin/devices/umi/package/data-store/ 2>&1 | head -20
echo "== 工作区里有没有现成 seed / NXSB 镜像"
find /home/unixnu/code/umi-work-pin/out -maxdepth 4 -iname '*ramdisk*' -o -maxdepth 4 -iname '*data*.img' 2>/dev/null | head -10
} > /mnt/e/Code/HackIos/out/probes/fw06-pre.txt 2>&1
echo WROTE
