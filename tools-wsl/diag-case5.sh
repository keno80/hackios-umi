#!/bin/bash
EDK2=/home/unixnu/code/Mu_Basecore
S=$EDK2/BaseTools/Source/Python/Common
{
echo '== gAllFiles 赋值点'
grep -rn "gAllFiles" $S/*.py $U 2>/dev/null | head -20
grep -rn "gAllFiles" $EDK2/BaseTools/Source/Python/Build.py 2>/dev/null | head -10
echo '== Misc.py 560-625 (GetRealPath 区)'
awk 'NR>=560 && NR<=625 {printf "%4d %s\n", NR, $0}' $S/Misc.py
echo '== uefi-umi-b 顶层符号链接'
find /home/unixnu/code/uefi-umi-b -maxdepth 3 -type l -printf '%p -> %l\n' 2>/dev/null | head -20
echo '== 谁引用 Mu_Basecore 路径（uefi-umi-b 内 .dsc/.fdf/.inc，排除 Build 目录）'
grep -rln "Mu_Basecore" /home/unixnu/code/uefi-umi-b --include=*.dsc --include=*.fdf --include=*.inc --include=*.dtsi 2>/dev/null | head -10
echo DONE
} > /mnt/e/Code/HackIos/out/probes/case-src2.txt 2>&1
