#!/bin/bash
set -u
exec > /mnt/e/Code/HackIos/out/probes/t16-amfi-sites.txt 2>&1
W=/home/unixnu/code/UniXNU-main/out/umi/tree/.cache/xnu-work
U=/home/unixnu/code/UniXNU-umi

echo "== 1. ubc_subr.c 里所有 amfi 相关行 =="
grep -n 'amfi' $W/bsd/kern/ubc_subr.c

echo
echo "== 2. 3925-3960（OSEntitlements_invalidate 上下文） =="
awk 'NR>=3925 && NR<=3960 {printf "%d\t%s\n", NR, $0}' $W/bsd/kern/ubc_subr.c

echo
echo "== 3. 4403-4421（要改的那段原文，逐字节） =="
awk 'NR>=4401 && NR<=4421 {printf "%d\t%s\n", NR, $0}' $W/bsd/kern/ubc_subr.c

echo
echo "== 4. amfi.h 的 _OSEntitlementsInterface 与 KPI 结构 =="
awk 'NR>=60 && NR<=135 {printf "%d\t%s\n", NR, $0}' $W/libkern/libkern/amfi/amfi.h

echo
echo "== 5. 设备仓里现有 umi-xnu 补丁清单（构建真正吃的这份） =="
ls -la $U/patches/umi-xnu/ 2>/dev/null | tail -20
echo "-- 仓库侧 --"
ls /mnt/e/Code/HackIos/patches/umi-xnu/ | wc -l
echo "-- 两边差异 --"
for p in /mnt/e/Code/HackIos/patches/umi-xnu/zz*.patch; do
  n=$(basename "$p")
  cmp -s "$p" "$U/patches/umi-xnu/$n" && echo "same $n" || echo "DIFF/MISSING $n"
done

echo
echo "== 6. 上一次内核构建日志尾部（确认基线可用） =="
L=$(cat /home/unixnu/code/UniXNU-main/out/unixnu-logs/latest.txt 2>/dev/null)
echo "latest=$L"
tail -5 "$L" 2>/dev/null
echo "done $(date -u +%FT%TZ)"
