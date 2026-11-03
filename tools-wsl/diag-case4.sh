#!/bin/bash
# 只读诊断：找 "in file system" 的抛出点与 AlterRoot 的来源；输出限长
EDK2=/home/unixnu/code/Mu_Basecore
S=$EDK2/BaseTools/Source/Python/Common
{
echo '== grep "in file system"'
grep -rn "in file system" $S | head -20
echo '== Misc.py 1540-1615'
awk 'NR>=1540 && NR<=1615' $S/Misc.py
echo '== grep AlterRoot'
grep -rn "AlterRoot" $S | head -30
echo '== Edk2Path 里 Root 的赋值（grep -n "self.Root" 前 30）'
grep -rn "self\.Root" $S/Edk2Path.py 2>/dev/null | head -30
echo DONE
} > /mnt/e/Code/HackIos/out/case-src.txt 2>&1
