#!/bin/bash
set -u
exec > /mnt/e/Code/HackIos/out/probes/t14-cs-null-and-apfs.txt 2>&1
W=/home/unixnu/code/UniXNU-main/out/umi/tree/.cache/xnu-work
T=/home/unixnu/code/UniXNU-main/out/umi/tree
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho

echo "== 1. accelerate_entitlement_queries 源码 =="
sed -n '4355,4400p' $W/bsd/kern/ubc_subr.c

echo
echo "== 2. 调用点上下文（ubc_cs_blob_add 内） =="
sed -n '4820,4870p' $W/bsd/kern/ubc_subr.c

echo
echo "== 3. 那个 NULL 全局是谁：0xfffffff0071c8228 =="
printf 'target offset in page 0x1c8000 -> 0x228\n'
llvm-nm -n --defined-only "$K" 2>/dev/null | awk '
  { v=strtonum("0x"$1) }
  v>=0xfffffff0071c8100 && v<=0xfffffff0071c8400 { print }' | head -20
echo "-- 附近符号（按名找 security/AMFI 表） --"
llvm-nm "$K" 2>/dev/null | grep -i "security_policy\|amfi\|_sad_\|mac_proc" | head -20

echo
echo "== 4. 这份树的 APFS 挂载来自哪 =="
echo "-- bsd/miscfs 下有什么 --"
ls $W/bsd/miscfs/ 2>/dev/null
echo "-- 有没有 apfs 的 vfsops 注册 --"
grep -rn "apfs" $W/bsd/vfs/vfs_syscalls.c 2>/dev/null | head -5
grep -rln "apfs_vfsop\|APFSVFSOps\|mountapfs" $W 2>/dev/null | head -10
echo "-- qemu-entry 里的 native apfs 配方 --"
sed -n '1,40p' $T/scripts/qemu-entry/native-apfs-mount.inc 2>/dev/null
echo "-- launchd 版 --"
sed -n '1,30p' $T/scripts/qemu-entry/native-apfs-launchd.inc 2>/dev/null

echo
echo "== 5. mkapfs 换个够大的容器试试（真 userdata 尺寸） =="
D=/tmp/apfst3; rm -rf $D; mkdir -p $D
truncate -s 2g $D/img
yes | mkapfs -L Data $D/img 2>&1 | head -20
echo "rc=$?"
ls -la $D/img
fsapfsinfo $D/img 2>&1 | head -15
echo "-- 建完后能否往里放文件（apfsprogs 无任何写文件工具，这里验证一下） --"
apfsck $D/img 2>&1 | head -10

echo
echo "== 6. linux-apfs-rw 能否真装起来 =="
apt-cache policy apfs-dkms 2>/dev/null | head -8
ls /usr/src/ 2>/dev/null | head
echo "done $(date -u +%FT%TZ)"
