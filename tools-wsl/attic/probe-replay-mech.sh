#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/f-replay.txt
: > "$OUT"
exec >>"$OUT" 2>&1
WS=/home/unixnu/code/umi-work-pin
echo "== umi-xnu 补丁在哪被重放 =="
grep -rn "umi-xnu" $WS/tools/*.py 2>/dev/null | head -20
echo
echo "== 重放用的命令（patch / git apply）=="
grep -rn -A4 "patches/umi-xnu" $WS/tools/*.py 2>/dev/null | head -40
echo
echo "== 装配树里的 patches/umi-xnu 是不是指向设备仓 =="
ls -la $WS/out/umi-xnu/umi/tree/patches/ 2>/dev/null
echo
echo "== 装配树里我们的补丁（按序）=="
ls -1 $WS/out/umi-xnu/umi/tree/patches/umi-xnu/ 2>/dev/null | tail -5
