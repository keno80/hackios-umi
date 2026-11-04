#!/bin/bash
# R 步之七：给 zalloc 这条 panic 加料之前，先确认要引用的符号在这棵树里真的存在、
# panic 串的两个调用点文本长什么样（补丁锚点必须逐字节唯一）。
set -u
LOG=/mnt/e/Code/HackIos/out/probes/r7-zidx-symbol.txt
: > "$LOG"
exec >> "$LOG" 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
Z=$X/osfmk/kern/zalloc.c

echo "== 1. ml_get_cpu_id / current_cpu 在 machine_routines.h 里有没有 =="
grep -rn "ml_get_cpu_id\|define current_cpu()" "$X/osfmk/arm/machine_routines.h" "$X/osfmk/arm64/machine_routines.h" 2>/dev/null | head -10
echo "-- zalloc.c 里已有的 cpu 取法 --"
grep -n "ml_get_cpu_id()\|current_cpu()\|cpu_number" "$Z" | head -12
echo
echo "== 2. zone_info.zi_meta_base / zi_meta_count 字段名 =="
grep -n "zi_meta_base\|zi_meta_count\|zi_meta_next_index" "$X/osfmk/kern/zalloc.h" "$Z" | head -12
echo
echo "== 3. zm_chunk_len 定义 =="
grep -n "zm_chunk_len" "$X/osfmk/kern/zalloc.h" | head -5
echo
echo "== 4. 两个调用点原文（补丁锚点）=="
awk 'NR>=973 && NR<=981 {printf "%5d  %s\n", NR, $0}' "$Z"
echo "-----"
awk 'NR>=1157 && NR<=1163 {printf "%5d  %s\n", NR, $0}' "$Z"
echo
echo "== 5. panic 语句原文（要替换的那 3 行）=="
awk 'NR>=773 && NR<=778 {printf "%5d  %s\n", NR, $0}' "$Z"
echo
echo "== 6. 锚点唯一性计数 =="
printf 'site978=%s site1161=%s panic775=%s\n' \
  "$(grep -c 'zone_page_metadata_index_confusion_panic(z, addr, meta);' "$Z")" \
  "$(grep -c 'zone_page_metadata_index_confusion_panic(zone, addr, meta);' "$Z")" \
  "$(grep -c 'but metadata has invalid zidx' "$Z")"
echo "== done $(date -u +%FT%TZ)"
