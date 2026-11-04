#!/bin/bash
# 接 s20：s20 找错了树（读的是 UniXNU-main/out/umi/tree，那是另一份未被我们补丁重放过的克隆）。
# 真正编译 S-WALK5 内核的树是 run-kernel-mockfs.sh 里的 TREE=
#   /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree
# 本文件要把「屏上 @zalloc.c:794」在这份文件里对应到哪一句 panic，从而分清
#   777（invalid zidx）与 794 是不是同一个失败模式。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s21-zalloc-build-tree.txt 2>&1
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree
Z=$T/osfmk/kern/zalloc.c

echo "== 0. 这份 zalloc.c 是否存在/新鲜 =="
ls -l --time-style=+%F_%T "$Z" 2>&1
sha256sum "$Z" 2>&1

echo
echo "== 1. 三条 zone panic 文案在构建树里的真实行号 =="
grep -n 'invalid zidx\|not in the expected zone\|metadata list corruption' "$Z"

echo
echo "== 2. 760..800 带行号（794 要落进窗口）=="
awk 'NR>=758 && NR<=802 {printf "%d\t%s\n", NR, $0}' "$Z"

echo
echo "== 3. 28z 在这份文件里插了什么（UMI28 / site= 全部命中行）=="
grep -n 'UMI28\|umi28\|site=\|zone_meta_validate' "$Z" | head -40

echo
echo "== 4. 构建树里 zalloc.c 的补丁来源：patches/umi-xnu 下动过 zalloc 的件 =="
P=$(ls -d "$T"/patches/* 2>/dev/null | head -20); echo "$P"
grep -rl 'zalloc' "$T"/patches/ 2>/dev/null | head

echo
echo "== 5. zone_meta_validate 本体（含探针）=="
awk 'NR>=960 && NR<=1040 {printf "%d\t%s\n", NR, $0}' "$Z"
