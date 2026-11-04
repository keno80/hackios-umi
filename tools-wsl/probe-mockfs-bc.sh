#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/mockfs-bc.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
S=/home/unixnu/code/UniXNU-main
W=/home/unixnu/code/umi-work-pin
X=$W/out/umi-xnu/umi/tree/.cache/xnu-work

say "== 1. mockfs 各 fsnode 的名字（lookup 靠什么名字命中）=="
grep -n 'name\|MOCKFS_ROOT\|MOCKFS_DEV\|MOCKFS_FILE' "$X/bsd/miscfs/mockfs/mockfs_fsnode.c" | head -30 >> "$OUT"
say "-- fsnode 结构/名字常量 --"
grep -rn 'mockfs_fsnode_name\|static.*name\[\]\|"dev"\|"file"\|"sbin"\|"launchd"' "$X/bsd/miscfs/mockfs/" | head -20 >> "$OUT"
say "-- vnops lookup 全文关键段 --"
grep -n -A18 'mockfs_lookup' "$X/bsd/miscfs/mockfs/mockfs_vnops.c" | head -60 >> "$OUT"

say
say "== 2. bsd_init 里挂上根之后 exec 谁 =="
grep -n 'INIT_PATH\|"/sbin/launchd"\|exec_init_process\|"rd"\|rootdev\|bsd_rooted_ramdisk' "$X/bsd/kern/bsd_init.c" | head -30 >> "$OUT"

say
say "== 3. rd= 与 memory-map/RAMDisk 的读取处 =="
grep -rn '"rd"' "$X/bsd/kern/" "$X/bsd/dev/" 2>/dev/null | head -10 >> "$OUT"
grep -n -B4 -A28 'RAMDisk' "$X/bsd/kern/IOKitBSDInit.cpp" 2>/dev/null | head -60 >> "$OUT"

say
say "== 4. run_umi_qemu：data_input / root_args / ramdisk 文件从哪来 =="
grep -n 'data_input\|data_ramdisk\|root_args\|ramdisk\|--initrd' "$W/tools/run_umi_qemu.py" | head -30 >> "$OUT"

say
say "== 5. make_umi_payload：--data-ramdisk 的处理（是否压缩/写到哪）=="
grep -n 'data_ramdisk\|ramdisk\|packed\|compress\|lzf\|lzav\|gzip' "$W/tools/make_umi_payload.py" | head -30 >> "$OUT"

say
say "== 6. darwinboot 侧谁把 RAMDisk 填成真实 base/size =="
grep -rln 'RAMDisk' "$S" 2>/dev/null | head -15 >> "$OUT"
say "-- 命中处的上下文 --"
grep -rn 'RAMDisk' "$S"/sources 2>/dev/null | head -20 >> "$OUT"
say done
