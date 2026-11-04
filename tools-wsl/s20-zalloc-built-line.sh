#!/bin/bash
# 接 s19：屏上写 @zalloc.c:794，但纯净 feed 里 "not in the expected zone" 那句在 787。
# 差值只可能是我们自己那批 z 补丁插进去的行数，所以必须拿「真正编译进去的那份 zalloc.c」对行号，
# 否则下次读屏会把两个不同 panic 混成一个。
# 顺带把 src_zone=[0] 到底是什么：屏上那对 %s%s 全空，说明 zone_array[0] 的 z_name/heap 是空的。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s20-zalloc-built-line.txt 2>&1
U=/home/unixnu/code/UniXNU-main
X=$U/out/feeds/xnu-0b4b910d

echo "== 1. 树里有几份 zalloc.c，各自大小/时间 =="
find "$U" -name zalloc.c -path '*osfmk/kern*' -printf '%TY-%Tm-%Td %TH:%TM %10s %p\n' 2>/dev/null | sort

echo
echo "== 2. 真正编译用的那份：761..800 带行号 =="
B=$(find "$U" -name zalloc.c -path '*osfmk/kern*' -newer "$X/Makefile" 2>/dev/null | head -1)
echo "  选用: ${B:-没找到}"
[ -n "$B" ] && awk 'NR>=755 && NR<=800 {printf "%d\t%s\n", NR, $0}' "$B"

echo
echo "== 3. 该份里两句文案各在哪一行（777 与 794 要对上）=="
[ -n "$B" ] && grep -n 'invalid zidx\|not in the expected zone\|metadata list corruption' "$B"

echo
echo "== 4. zone_has_index / num_zones 的定义 =="
grep -n 'zone_has_index' "$X/osfmk/kern/zalloc.c" | head -8
awk '/^zone_has_index/{f=1} f{print NR"\t"$0} f&&/^}/{exit}' "$X/osfmk/kern/zalloc.c"

echo
echo "== 5. zidx 0 是哪个 zone：静态表头几项与 ZONE_ID 枚举 =="
grep -n 'ZONE_ID_ZONE\b\|ZONE_ID_ARRAY\|ZONE_ID__FIRST_DYNAMIC\|ZONE_ID__LAST_RO\|ZONE_ID_VM_MAP\b' "$X/osfmk/kern/zone_types.h" | head -20
echo "--- 静态 zone 表前 8 行："
awk '/^\(zone_t\) &zone_array\[ZONE_ID_ARRAY_FIRST\]|static zone_static_data|_static_zones\[\]/{f=1} f{print NR"\t"$0} f&&/^};/{exit}' "$X/osfmk/kern/zalloc.c" | head -30

echo
echo "== 6. zone_heap_name：为什么 %s%s 打出来是空 =="
grep -rn 'zone_heap_name' "$X/osfmk/kern/zone_types.h" "$X/osfmk/kern/zalloc.c" | head -8
awk '/zone_heap_name/{f=1} f{print NR"\t"$0} f&&/^}/{c++; if(c==1) exit}' "$X/osfmk/kern/zalloc.c" | head -20

echo
echo "== 7. 我们那批 z 补丁在哪、有没有动 zalloc.c =="
ls "$U/patches" 2>/dev/null
for d in "$U/patches"/*/; do
  grep -rl 'zalloc' "$d" 2>/dev/null | head -5
done
echo "--- 命中 UMI28 的文件："
grep -rl 'UMI28' "$U" 2>/dev/null | head -10
