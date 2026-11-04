#!/bin/bash
# R 步之六：这条 panic 只能由「某个操作发现页元数据的 zidx 不属于自己」触发。
# 调用点决定语义——是分配、释放、还是页元数据搬迁——先把它钉死，再谈修法。
set -u
LOG=/mnt/e/Code/HackIos/out/probes/r6-zidx-callers.txt
: > "$LOG"
exec >> "$LOG" 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
Z=$X/osfmk/kern/zalloc.c

echo "== 1. zone_page_metadata_index_confusion_panic 的调用点 =="
grep -n "zone_page_metadata_index_confusion_panic" "$Z"
echo
echo "== 2. 每个调用点上下文（前后 14 行）=="
for L in $(grep -n "zone_page_metadata_index_confusion_panic(" "$Z" | grep -v "^761" | cut -d: -f1); do
  echo "----- 调用点 $L -----"
  awk -v s=$((L-16)) -v e=$((L+4)) 'NR>=s && NR<=e {printf "%5d  %s\n", NR, $0}' "$Z"
done
echo
echo "== 3. zm_index 的写入点（谁负责把它填对）=="
grep -n "zm_index =\|zm_index=" "$Z" | head -20
echo
echo "== 4. num_zones 的推进点 =="
grep -n "num_zones" "$Z" | head -20
echo
echo "== 5. MAX_ZONES 实际值 =="
grep -rn "define MAX_ZONES\|MAX_ZONES " "$X/osfmk/kern/zalloc.h" "$X/osfmk/arm/vm_machine.h" 2>/dev/null | head -10
grep -rn "MAX_ZONES" "$Z" | head -5
echo "== done $(date -u +%FT%TZ)"
