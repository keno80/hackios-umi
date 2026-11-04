#!/bin/bash
# 两处 ECHILD 探针所在函数与 p 的来历：谁可能已经是 NULL。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/n14-wait4-sites.txt
: > "$OUT"
exec >>"$OUT" 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
F=$X/bsd/kern/kern_exit.c

echo "== 1. 两处站点的行号（打过 25z 之后）=="
grep -n 'WAIT4 A none\|WAIT4 B none' "$F"

echo
echo "== 2. 站点 A 前后 60 行 =="
A=$(grep -n 'WAIT4 A none' "$F" | cut -d: -f1)
sed -n "$((A-70)),$((A+12))p" "$F" | nl -ba -v$((A-70))

echo
echo "== 3. 站点 A 所在函数（往上找定义）=="
awk -v a="$A" 'NR<=a && /^[A-Za-z_].*\(/ {last=NR": "$0} END{print last}' "$F"

echo
echo "== 4. 站点 B 前后 40 行 =="
B=$(grep -n 'WAIT4 B none' "$F" | cut -d: -f1)
sed -n "$((B-30)),$((B+12))p" "$F" | nl -ba -v$((B-30))
echo "-- 站点 B 所在函数 --"
awk -v b="$B" 'NR<=b && /^[A-Za-z_].*\(/ {last=NR": "$0} END{print last}' "$F"

echo
echo "== 5. 该函数里 p 的赋值轨迹（找 p = NULL / PROC_NULL）=="
sed -n '2900,3130p' "$F" | grep -n 'p = \|p=NULL\|PROC_NULL\|proc_t p' | head -30

echo
echo "== 6. wait4_nocancel 的原型 =="
grep -n 'wait4_nocancel' "$F" | head
echo "== done $(date -u +%FT%TZ)"
