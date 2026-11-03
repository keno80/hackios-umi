#!/bin/bash
# 摸 #15 备选：树内 mockfs 根需要哪些开关与前置件（只读）
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree
{
echo "== build-xnu-4k-baseline.sh 里 MOCKFS 相关行"
grep -n "MOCKFS\|mockfs" /home/unixnu/code/umi-work-pin/sources/UniXNU/scripts/build-xnu-4k-baseline.sh | head -40

echo "== umi_defconfig 里 MOCKFS/NULL_ROOT"
grep -rn "MOCKFS\|NULL_ROOT\|VERIFIED_ROOT" /home/unixnu/code/umi-work-pin/devices/umi/*.config /home/unixnu/code/umi-work-pin/devices/umi/ 2>/dev/null | head -20

echo "== 前置件是否存在：vfs_conf.o.json 配方"
ls -l $T/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/bsd/DEVELOPMENT/vfs_conf.o.json 2>&1 | tail -1
echo "== mockfs 源文件"
ls $T/.cache/xnu-work/bsd/miscfs/mockfs/ 2>&1 | head -10
echo "== 已产出的 mockfs fixture?"
ls -l $T/build/mockfs-fixture/ 2>&1 | head -8
echo "== build_umi_xnu.py 里 original-mockfs 步骤与开关"
grep -n "mockfs\|MOCKFS" /home/unixnu/code/umi-work-pin/tools/build_umi_xnu.py | head -20
echo "== run-kernel-ownerroot.sh 里有没有 mockfs 选项"
grep -n "mockfs\|MOCKFS\|NULL_ROOT" /mnt/e/Code/HackIos/tools-wsl/*.sh 2>/dev/null | head -10
} > /mnt/e/Code/HackIos/out/mockfs-route.txt 2>&1
echo WROTE
