#!/bin/bash
# 查 25z 探针补丁的现场：xnu-work 里打过没有、补丁文件叫什么、还有谁改过这两个文件。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/n15-forkprobe-state.txt
: > "$OUT"
exec >>"$OUT" 2>&1

WS=/home/unixnu/code/umi-work-pin
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work
DEV=/home/unixnu/code/UniXNU-umi
ARCH=/mnt/e/Code/HackIos/patches/umi-xnu

echo "== 1. xnu-work 是否已含 25z 文本 =="
for S in 'WAIT4 A none' 'FORK cpid=' 'REAP cpid='; do
  printf '%s -> kern_exit=%s kern_fork=%s\n' "$S" \
    "$(grep -c -- "$S" "$X/bsd/kern/kern_exit.c")" \
    "$(grep -c -- "$S" "$X/bsd/kern/kern_fork.c")"
done

echo
echo "== 2. z 系补丁清单（名字长度即序）=="
cd "$DEV/patches/umi-xnu" || exit 1
for f in $(ls | grep '^z' | sort); do
  printf '%2d  %s  %s\n' "$(printf '%s' "${f%%-*}" | wc -c)" "$f" "$(sha256sum "$f" | cut -c1-12)"
done

echo
echo "== 3. 谁还改过 kern_exit.c / kern_fork.c =="
grep -l 'bsd/kern/kern_exit.c\|bsd/kern/kern_fork.c' *.patch | while read -r f; do
  printf '%s  z=%s\n' "$f" "$(printf '%s' "${f%%-*}" | wc -c)"
done

echo
echo "== 4. ECHILD 两处现在长什么样（xnu-work 实况）=="
grep -n -B2 -A4 'WAIT4 A none\|WAIT4 B none' "$X/bsd/kern/kern_exit.c"

echo
echo "== 5. waitid_nocancel 站点 B 附近 q 的可空线索 =="
sed -n '3217,3245p' "$X/bsd/kern/kern_exit.c"

echo
echo "== 6. 三份 25z 是否同一份（ext4 设备仓 / Windows 归档 / 上一段记录的哈希）=="
find /home/unixnu/code/UniXNU-umi/patches/umi-xnu /mnt/e/Code/HackIos/patches/umi-xnu \
  -name '*fork-probe*' -printf '%s %p\n' -exec sha256sum {} +
echo done
