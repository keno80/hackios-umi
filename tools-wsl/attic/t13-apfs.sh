#!/bin/bash
set -u
exec > /mnt/e/Code/HackIos/out/probes/t13-apfs-and-cscrash.txt 2>&1
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho
T=/home/unixnu/code/UniXNU-main/out/umi/tree

echo "== 1. 崩溃点反汇编：_accelerate_entitlement_queries 头 40 条 =="
llvm-objdump -d --start-address=0xfffffff007787a74 --stop-address=0xfffffff007787ae0 "$K" 2>&1 | tail -30

echo
echo "== 2. 该函数引用的全局符号（找 NULL 的那个） =="
llvm-objdump -d --start-address=0xfffffff007787a74 --stop-address=0xfffffff007787b40 "$K" 2>&1 | grep -o '<_[A-Za-z0-9_.]*>' | sort -u | head -30

echo
echo "== 3. 源码里这个函数在哪 =="
grep -rn "accelerate_entitlement_queries" $T --include=*.c --include=*.h 2>/dev/null | head -10
echo "-- ubc_cs_blob_add 里的调用 --"
grep -rn "ubc_cs_blob_add" $T/bsd/kern/*.c $T/security/*.c 2>/dev/null | head -10

echo
echo "== 4. 这份树里到底有没有 APFS 驱动 =="
find $T -iname '*apfs*' -not -path '*/.git/*' 2>/dev/null | head -30
echo "-- 内核挂载的文件系统注册表 --"
grep -rn "^struct vfsops\|vfsops64\|_apfs_vfsops\|apfs_vfsop_table" $T/bsd/vfs/*.c 2>/dev/null | head -20
echo "-- mockfs 之外的 fs 列表 --"
ls $T/bsd/miscfs/ 2>/dev/null

echo
echo "== 5. 上游 umi 记录里 Data 种子是哪一步要的 =="
find /home/unixnu/code/UniXNU-main/docs -name '*.toml' 2>/dev/null | head -20
grep -rln "data-seed\|data_seed\|make-data-seed" /home/unixnu/code/UniXNU-main --include=*.md --include=*.toml --include=*.py 2>/dev/null | head -20

echo
echo "== 6. data 种子在 umi 流程里是否必需：看 root 挂载选择 =="
grep -rn "rootdev\|/dev/disk" /home/unixnu/code/UniXNU-main/out/umi/tree/scripts/*.py 2>/dev/null | grep -i "data\|apfs" | head -20

echo
echo "== 7. Linux 侧 APFS 写通路终判 =="
echo "-- mkapfs 能否直接吃一个普通文件（非分区） --"
D=/tmp/apfst2; rm -rf $D; mkdir -p $D
truncate -s 32m $D/img
mkapfs -L Data $D/img 2>&1 | head -20
echo "rc=$?"
echo "-- 造出来的镜像能否被 fsapfsinfo 认 --"
fsapfsinfo $D/img 2>&1 | head -20
echo "-- apfs-dkms 状态 --"
dkms status 2>&1 | head -10
ls /var/lib/dkms/apfs 2>&1 | head -5
echo "-- apfsprogs 能否往卷里写文件（查包内二进制清单） --"
dpkg -L apfsprogs | grep -v '/man/' | tail -10
echo "done $(date -u +%FT%TZ)"
