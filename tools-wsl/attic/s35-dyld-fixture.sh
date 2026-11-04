#!/bin/bash
# 接 s31 的重大发现：内核 mockfs 的 N4KROOT 分支**天生支持两个文件**（launch + test），
# 而且上游已经有 scripts/build-target-dyld-fixture.py —— 它打包的就是「真 launchd + 真 dyld」。
# 也就是说「塞一个真 Apple 件进假根 exec」这一发，上游可能已经把配方写好了。
# 本文件把三件事一次读全：
#   1) build-target-dyld-fixture.py 全文：真件从哪来、偏移怎么摆、有没有 Darwin 依赖；
#   2) mockfs_vfsops.c 的 N4KROOT 分支全文 + 两个 fsnode 的名字是哪来的；
#   3) 上游对这条路的验收判据（check-original-cache-file-checkpoints.py 与 probe 里的键名）。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s35-dyld-fixture.txt 2>&1
U=/home/unixnu/code/UniXNU-main
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree
MV=$T/.cache/xnu-work/bsd/miscfs/mockfs/mockfs_vfsops.c

echo "== 1. build-target-dyld-fixture.py 全文 =="
cat -n "$U/scripts/build-target-dyld-fixture.py" 2>/dev/null || echo "  UniXNU-main 里没有，找 umi-work-pin"
ls -l "$T/scripts/build-target-dyld-fixture.py" 2>/dev/null

echo
echo "== 2. mockfs_vfsops.c 的 N4KROOT 分支（100..200 行）=="
awk 'NR>=95 && NR<=205 {printf "%d\t%s\n", NR, $0}' "$MV"

echo
echo "== 3. 两个 fsnode 的名字与 vnops 暴露（mockfs_fsnode.c 里 name 赋值）=="
grep -n 'name\|launchd\|probe' "$T/.cache/xnu-work/bsd/miscfs/mockfs/mockfs_fsnode.c" | head -40

echo
echo "== 4. 上游对 dyld fixture 的验收键 =="
grep -rn 'target-dyld\|target_dyld\|dyld_fixture\|native_dyld' "$U/scripts" 2>/dev/null | grep -v '\.pyc' | head -20

echo
echo "== 5. check-original-cache-file-checkpoints.py 全文 =="
cat -n "$U/scripts/check-original-cache-file-checkpoints.py" 2>/dev/null | head -60
