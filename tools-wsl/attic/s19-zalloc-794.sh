#!/bin/bash
# S-WALK5 第一次上机那条红屏的取数：屏上原文
#   UMI PANIC ... not in the expected zone  VM map entries[16], but found in [0]
#   UMI28 nz=393 cpu=0 slot=4280295505 site=validate  @zalloc.c:794  UMI marks=745 tail=5 grid=41x42
# 要分清两件事：
#   1) 794 行这个 panic 是不是 28z 探针自己加的，还是上游原生（决定「谁在报」）；
#   2) 它与已知的 invalid zidx: 64 @zalloc.c:777 是不是同一个失败模式（行号不同、site 不同）。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s19-zalloc-794.txt 2>&1
X=/home/unixnu/code/UniXNU-main/out/feeds/xnu-0b4b910d
U=/home/unixnu/code/UniXNU-main

echo "== 1. zalloc.c 740..830 全文（带行号，794 和 777 都要在窗口里）=="
awk 'NR>=740 && NR<=830 {printf "%d\t%s\n", NR, $0}' "$X/osfmk/kern/zalloc.c"

echo
echo "== 2. 这两句报错文案在本树哪里（原生 or 我们注入）=="
grep -rn 'not in the expected zone' "$X/osfmk/kern/zalloc.c"
grep -rn 'invalid zidx' "$X/osfmk/kern/zalloc.c"

echo
echo "== 3. 794 行所属函数：往上找最近的函数定义 =="
awk 'NR<=800 && /^[a-zA-Z_].*\(/ {last=NR": "$0} END{}' /dev/null
for n in 794 777; do
  echo "--- 第 $n 行，往上 60 行里最近的非缩进行："
  awk -v N="$n" 'NR<=N && /^[^ \t].*[(].*\)/ {line=NR": "$0} NR==N {print "  锚点 -> " line}' "$X/osfmk/kern/zalloc.c"
done

echo
echo "== 4. zone_meta_validate 本体 =="
grep -n 'zone_meta_validate' "$X/osfmk/kern/zalloc.c" | head -20
echo "--- 定义体："
awk '/^zone_meta_validate|static.*zone_meta_validate/{f=1} f{print NR"\t"$0} f&&/^}/{exit}' "$X/osfmk/kern/zalloc.c" | head -80

echo
echo "== 5. 「VM map entries」这个 zone 在本档是动态 spawn 还是静态 primordial =="
grep -rn 'VM map entries' "$X/osfmk/kern/"*.c "$X/osfmk/kern/"*.h 2>/dev/null | head -10
grep -rn 'VM map entries' "$X/bsd/kern/"*.c 2>/dev/null | head -5

echo
echo "== 6. zone 索引是怎么定的：zone_sort_and_coalesce / zone_init 里给 zid 赋值的顺序 =="
grep -n 'zid = \|zone->zid\|realzone_index\|static_zone_table\|dynamic_zone_table' "$X/osfmk/kern/zalloc.c" | head -40

echo
echo "== 7. 28z 探针本体（屏上 UMI28 nz= / slot= / site= 是它打的）=="
ls "$U/patches/umi-xnu/" 2>/dev/null | tail -20
grep -rln 'UMI28\|site=validate\|not in the expected zone' "$U/patches/umi-xnu/" 2>/dev/null

echo
echo "== 8. 8z/28z 那段补丁全文（只看 panic 打印处）=="
for f in $(grep -rln 'UMI28' "$U/patches/umi-xnu/" 2>/dev/null); do
  echo "--- $f"
  grep -n 'UMI28\|nz=\|slot=\|site=\|marks=\|grid=' "$f" | head -30
done
