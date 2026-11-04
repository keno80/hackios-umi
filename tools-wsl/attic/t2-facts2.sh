#!/bin/bash
# T 步事实核对（二）：mockfs 容器里两个节点的路径名、init_programs 清单、原版 trustcache 在哪
set -u
exec > /mnt/e/Code/HackIos/out/probes/t2-facts2.txt 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
U=/home/unixnu/code/UniXNU-main
W=/home/unixnu/code/umi-work-pin

echo "== 1. mockfs 目录清单 =="
ls "$X/bsd/miscfs/mockfs/" 2>&1

echo
echo "== 2. fsnode 名字：ROOT/DEV/FILE/TEST_FILE 各自挂什么路径 =="
grep -n -B10 -A40 'MOCKFS_TEST_FILE' "$X/bsd/miscfs/mockfs/mockfs_fsnode.c" 2>/dev/null | head -100

echo
echo "== 3. init_programs[] 全文 =="
sed -n '7440,7470p' "$X/bsd/kern/kern_exec.c"

echo
echo "== 4. mockfs_vfsops 里 N4KROOT 之外，legacy 模式下 file_fsnode 的 size/offset 从哪来 =="
grep -n 'backing_offset\|->size\|MOCKFS_FILE\|MOCKFS_DEV\|MOCKFS_ROOT' \
  "$X/bsd/miscfs/mockfs/mockfs_vfsops.c" 2>/dev/null | head -30

echo
echo "== 5. 上游要求的原版 trust bundle（sha 7416ca4f…）在哪 =="
find /home/unixnu/code -maxdepth 8 -iname '*trust*' \( -name '*.bin' -o -name '*.bundle' -o -name '*.ctbt' \) 2>/dev/null | head -20
echo "-- 逐个 sha256 --"
for f in $(find /home/unixnu/code -maxdepth 8 -iname '*trust*' \( -name '*.bin' -o -name '*.bundle' \) 2>/dev/null | head -20); do
  printf '%s  %s\n' "$(sha256sum "$f" | cut -c1-64)" "$f"
done
echo "-- 代码里引用 trustcache 路径的地方 --"
grep -rn 'kernel.macho.trustcache\|trust_cache\|trustcache' "$W/tools/run_umi_qemu.py" 2>/dev/null | head -20
grep -rln '7416ca4f8377146626bb284e2133c76bee6cb4e3ee0af5d648b186235a7323a7' "$U" "$W" 2>/dev/null | head -10

echo
echo "== 6. 我们的真机 payload 工具能不能带 trustcache =="
grep -n 'trust' /mnt/e/Code/HackIos/tools-wsl/build-xnu-payload.py | head -10
echo "== done $(date -u +%FT%TZ)"
