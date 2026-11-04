#!/bin/bash
# R 步之二：把 zalloc.c:777 这条 panic 的原文与判定链取出来。
# 上一版脚本把 zalloc.c 猜在 os/ 与 vm/ 下（实际在 osfmk/kern/），空跑一轮。
set -u
LOG=/mnt/e/Code/HackIos/out/probes/r2-zalloc-site.txt
: > "$LOG"
exec >> "$LOG" 2>&1

W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi
X=$W/tree/.cache/xnu-work
Z=$X/osfmk/kern/zalloc.c
K=$X/osfmk/kern/kalloc.c

echo "== 0. 文件指纹 =="
ls -la "$Z" "$K" | sed 's#^# #'
echo

echo "== 1. panic 原文（zalloc.c:755-800）=="
awk 'NR>=755 && NR<=800 {printf "%4d  %s\n", NR, $0}' "$Z"
echo

echo "== 2. 这条 panic 的字符串在哪几处、各自什么条件 =="
grep -n "expected in zone\|invalid zidx\|zidx" "$Z" | head -40
echo

echo "== 3. 所在函数（往上找最近的函数定义头）=="
awk 'NR<=777 && /^[a-zA-Z_][a-zA-Z_0-9 \*]*\(/ {last=NR": "$0} END{print last}' "$Z"
echo

echo "== 4. kt_fixed_zones 的定义与用法 =="
awk 'NR>=440 && NR<=460 {printf "%4d  %s\n", NR, $0}' "$K"
echo "-- 用法处 --"
awk 'NR>=1745 && NR<=1775 {printf "%4d  %s\n", NR, $0}' "$K"
echo

echo "== 5. zone 名字带 [%d] 的打印来自哪里（subzone? zone index?）=="
grep -n "z_zone_name" "$Z" | head -20
echo

echo "== 6. VM map entries 这个 zone 从哪注册（找 ZONENAME 宏）=="
grep -rn "VM_MAP_ENTRY_ZONENAME\|vm_map_entry.*ZONENAME" "$X" --include=*.c --include=*.h | head -5
grep -rn "ZONENAME" "$X/vm/vm_map.c" | head -5
echo
echo "== 7. 静态 zone 表容量与 zidx 位宽 =="
grep -n "zone_table_array_elements\|MAX_ZONES\|zidx_t\|ZID_.*BITS\|zone_ref_bits" "$Z" "$X/osfmk/kern/zalloc.h" 2>/dev/null | head -25
echo "== done $(date -u +%FT%TZ)"
