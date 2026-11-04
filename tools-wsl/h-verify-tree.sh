#!/bin/bash
# H 步核对：band 是否进了构建树、start.o 是否编出、构建是否还活着
set -u
TREE=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree
OUT=/mnt/e/Code/HackIos/out/probes/h-tree-check.txt
exec >"$OUT" 2>&1

echo "== 树里 start.s 的 band/trace 落点 =="
grep -n "UMI_BAND\|UMI_TRACE 0x0" "$TREE/.cache/xnu-work/osfmk/arm64/start.s" 2>&1 | head -10

echo
echo "== 树里的 umi-early-trace.inc 有 UMI_BAND 吗 =="
find "$TREE" -name "umi-early-trace.inc" 2>/dev/null | while read -r f; do
  echo "$f band=$(grep -c 'macro UMI_BAND' "$f")"
done

echo
echo "== start.o 产出与时间 =="
find "$TREE" -name "start.o" -path "*arm64*" -printf "%T@ %p\n" 2>/dev/null | sort -rn | head -3

echo
echo "== 构建进程 =="
ps -o pid,etime,cmd -p "$(cat /home/unixnu/code/UniXNU-main/out/unixnu-logs/kernel-trace.pid)" 2>&1 | tail -2

echo
echo "== 内核日志里 start.s 相关报错 =="
L=$(ls -t "$TREE"/logs/*/kernel.log 2>/dev/null | head -1)
echo "log=$L"
grep -n -i "start\.s\|UMI_BAND\|umi-early-trace" "$L" 2>/dev/null | grep -i "error\|warning\|failed" | head -8

echo
echo "== 最新 trace 内核 =="
ls -l "$TREE/../kernel/" 2>/dev/null | tail -4
