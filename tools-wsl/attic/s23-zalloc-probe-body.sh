#!/bin/bash
# 接 s22：真正编进 S-WALK5 内核的那份 zalloc.c 在
#   $T/.cache/xnu-work/osfmk/kern/zalloc.c（302116 B，2026-11-04 16:50，比 feed 那份大 3823 B = 我们插的行）
# 本文件一次性把三件事钉死：
#   a) 屏上 @zalloc.c:794 在构建树对应哪一句；
#   b) zidx 探针（28z）具体插在哪、打印的 nz=/slot=/site= 从哪个变量来；
#   c) zone_meta_validate 与 zone_page_metadata_index_confusion_panic 的调用关系。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s23-zalloc-probe-body.txt 2>&1
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree
Z=$T/.cache/xnu-work/osfmk/kern/zalloc.c
P=$T/patches/umi-xnu/zzzzzzzzzzzzzzzzzzzzzzzzzzzz-umi-zidx-probe.patch

echo "== 1. 构建树 zalloc.c 里三条 zone panic 的行号 =="
grep -n 'invalid zidx\|not in the expected zone\|metadata list corruption' "$Z"

echo
echo "== 2. 745..800 带行号 =="
awk 'NR>=745 && NR<=800 {printf "%d\t%s\n", NR, $0}' "$Z"

echo
echo "== 3. 探针相关标识在构建树里的全部命中 =="
grep -n 'UMI28\|umi_zidx\|zidx_probe\|site=\|nz=%\|slot=%' "$Z" | head -30

echo
echo "== 4. 28z 补丁全文 =="
cat "$P"

echo
echo "== 5. zone_meta_validate（构建树）=="
grep -n 'zone_meta_validate' "$Z" | head
awk '/^zone_meta_validate/{f=1} f{print NR"\t"$0} f&&/^}/{exit}' "$Z"
