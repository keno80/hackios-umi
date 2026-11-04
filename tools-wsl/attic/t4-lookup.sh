#!/bin/bash
# T 步事实核对（四）：mockfs_lookup 全量名字映射（决定哪个槽给哪个路径）
set -u
exec > /mnt/e/Code/HackIos/out/probes/t4-lookup.txt 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== mockfs_lookup 全文（120..200 行）=="
sed -n '118,205p' "$X/bsd/miscfs/mockfs/mockfs_vnops.c"
echo
echo "== mockfs_read / pagein 是否按 backing_offset 偏移 =="
grep -n -A12 'backing_offset' "$X/bsd/miscfs/mockfs/mockfs_vnops.c" | head -60
echo
echo "== fsnode 结构定义 =="
grep -n -B3 -A12 'struct mockfs_fsnode' "$X/bsd/miscfs/mockfs/mockfs.h" | head -40
echo "== done $(date -u +%FT%TZ)"
