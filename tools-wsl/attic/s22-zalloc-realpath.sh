#!/bin/bash
# 接 s21：构建树根 $T 下没有 osfmk/（XNU 源码在 $T/build/xnu 之类的子目录）。
# 先把 zalloc.c 的真实位置找出来，再对行号；同时列出 patches/umi-xnu 里动 zalloc 的那个件。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s22-zalloc-realpath.txt 2>&1
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree

echo "== 1. 这棵树里所有 zalloc.c =="
find "$T" -name zalloc.c -printf '%TY-%Tm-%Td %TH:%TM %10s %p\n' 2>/dev/null | sort

echo
echo "== 2. patches/umi-xnu 清单（按名字排序，看 z 前缀重放顺序）=="
ls "$T/patches/umi-xnu/" | sort | tail -30

echo
echo "== 3. 哪些补丁动了 zalloc.c =="
grep -rl 'zalloc' "$T/patches/umi-xnu/" 2>/dev/null

echo
echo "== 4. UMI28 探针在哪个补丁里，全文 =="
for f in $(grep -rl 'UMI28' "$T/patches/umi-xnu/" 2>/dev/null); do
  echo "--- $f"
  cat -A /dev/null >/dev/null
  awk 'NR<=200 {print NR"\t"$0}' "$f"
done
