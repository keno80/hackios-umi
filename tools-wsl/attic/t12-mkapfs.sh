#!/bin/bash
set -u
exec > /mnt/e/Code/HackIos/out/probes/t12-mkapfs-panic.txt 2>&1
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho
echo "== 0. 内核身份 =="
sha256sum "$K"

echo
echo "== 1. panic 符号化：pc/lr/ELR 落在哪个符号 =="
for A in 0xfffffff007787a90 0xfffffff0077866dc 0xfffffff007289e40 0xfffffff00742afa4 0xfffffff00728ab20; do
  echo "-- $A --"
  llvm-nm -n --defined-only "$K" 2>/dev/null | awk -v a="$A" '
    BEGIN{target=strtonum(a)}
    /^[0-9a-f]+ [A-Za-z] /{ v=strtonum("0x"$1); if(v<=target){last=v; lsym=$3} }
    END{ if(lsym!="") printf "  %s + 0x%x\n", lsym, target-last; else print "  (no symbol)" }'
done

echo
echo "== 2. 反汇编 lr 调用点上下文 =="
S=$(printf '0x%x' $((0xfffffff0077866dc - 0x40)))
llvm-objdump -d --start-address=0xfffffff0077866a0 --stop-address=0xfffffff007786700 "$K" 2>&1 | tail -30

echo
echo "== 3. mkapfs 能力实测 =="
mkapfs --help 2>&1 | head -30
echo "-- version --"
dpkg -l apfsprogs 2>/dev/null | tail -2

echo
echo "== 4. 纯 Linux 造一个 32MiB APFS 容器 =="
D=/tmp/apfstest; rm -rf $D; mkdir -p $D
IMG=$D/data.img
truncate -s 32m "$IMG"
parted -s "$IMG" mklabel gpt mkpart 1 1MiB 31MiB 2>&1 | head -5
LOOP=$(losetup -f --show "$IMG" 2>/dev/null)
echo "loop=$LOOP"
if [ -n "$LOOP" ]; then
  PART=$(ls ${LOOP}p1 2>/dev/null || ls ${LOOP}1 2>/dev/null)
  echo "part=$PART"
  if [ -n "$PART" ]; then
    echo "-- mkapfs -v 输出 --"
    yes | mkapfs -v "$PART" 2>&1 | head -40
    echo "-- rc=$? --"
    echo "-- apfsck --"
    apfsck "$PART" 2>&1 | head -20
    echo "-- pyfsapfs 能否打开 --"
    python3 -c "
import fsapfs
s=fsapfs.apfs_container()
s.open('$PART')
print('volumes:',[s.get_volume(i).name for i in range(s.number_of_volumes)])
" 2>&1 | head -10
  fi
  losetup -d "$LOOP" 2>/dev/null
  losetup -d "$LOOP" 2>/dev/null
  kpartx -d "$IMG" 2>/dev/null
fi

echo
echo "== 5. Linux 侧有没有『往 APFS 卷里加文件』的写通路 =="
for t in mkapfs apfsck apfs-snap fsapfsinfo dump-apfs apfs-fuse mount.apfs; do
  printf '%-14s %s\n' "$t" "$(command -v $t || echo -)"
done
echo "-- apfs-dkms 是否已装 --"
dpkg -l apfs-dkms 2>/dev/null | tail -2
echo "-- 内核里有没有 apfs 模块 --"
modinfo apfs 2>&1 | head -5
echo "-- apfsprogs 包里 mkapfs 的 man --"
man mkapfs 2>/dev/null | col -b | head -40

echo
echo "== 6. 我们这份 XNU 的 APFS 驱动挂载是否要求可写 =="
T=/home/unixnu/code/UniXNU-main/out/umi/tree
grep -rn "APFS\|apfs" $T/bsd/vfs/vfs_syscalls.c 2>/dev/null | head -10
echo "-- mount 时 ffs/mount_apfs 相关 --"
ls $T/bsd/apfs 2>/dev/null | head -20
ls $T/bsd/hfs 2>/dev/null | head -5
echo "done $(date -u +%FT%TZ)"
