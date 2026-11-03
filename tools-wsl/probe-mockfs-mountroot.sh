#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/mockfs-mountroot.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
M=$X/bsd/miscfs/mockfs

say "== 1. mockfs_mountroot 全文 =="
L=$(grep -n 'mockfs_mountroot' "$M/mockfs_vfsops.c" | tail -1 | cut -d: -f1)
say "L=$L"
sed -n "$((L-6)),$((L+95))p" "$M/mockfs_vfsops.c" >> "$OUT" 2>&1

say
say "== 2. 内存背书的判定（谁给出 base）=="
grep -n 'memory_backed\|physical_memory\|memdev_base\|memdev_size\|D_MEM\|md_dev\|si_devsize\|specinfo' "$M"/*.c "$M"/*.h | head -25 >> "$OUT"

say
say "== 3. memdev 侧提供的接口 =="
grep -n 'mdev_info\|mdinfo\|MD_INFOSZ\|DKIODINFO\|mdevgetrange\|struct mdinfo' "$X/bsd/dev/memdev.c" | head -20 >> "$OUT"
say "-- CONFIG_MEMDEV_INSECURE 包住的具体函数（485..548 的签名）--"
sed -n '483,492p;544,552p' "$X/bsd/dev/memdev.c" >> "$OUT" 2>&1

say
say "== 4. vfs_conf.c 里 mock 候选前后的候选顺序 =="
sed -n '150,215p' "$X/bsd/vfs/vfs_conf.c" >> "$OUT" 2>&1
say done
