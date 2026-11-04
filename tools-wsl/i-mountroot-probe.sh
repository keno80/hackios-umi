#!/bin/bash
# 挂根探针前置核对：vfs_mountroot 的实现位置与失败分支，bsd_init.c 里可用的格式化函数。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/i-mountroot-probe.txt
: > "$OUT"
exec >>"$OUT" 2>&1

X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== 0. 工作树在不在 =="
ls -d "$X" || exit 1
ls "$X" | head -20

echo
echo "== 1. vfs_mountroot 的定义文件 =="
grep -rn "^vfs_mountroot\|^int$" "$X/bsd/vfs" 2>/dev/null | grep -B0 vfs_mountroot | head
grep -rln "vfs_mountroot(void)" "$X/bsd" 2>/dev/null | head -20

echo
echo "== 2. 全树搜 vfs_mountroot 出现处 =="
grep -rn "vfs_mountroot" "$X/bsd" 2>/dev/null | head -30

echo
echo "== 3. bsd_init.c 里可用的格式化函数 =="
grep -n "snprintf\|sprintf\|libkern.h" "$X/bsd/kern/bsd_init.c" | head -20

echo
echo "== 4. rootdevice 的声明与写入 =="
grep -rn "rootdevice\[" "$X/bsd" 2>/dev/null | head -20

echo
echo "== 5. 现有 umi-xnu 补丁名与 z 数 =="
ls -la /home/unixnu/code/UniXNU-umi/patches/umi-xnu/ | tail -8
for f in /home/unixnu/code/UniXNU-umi/patches/umi-xnu/*.patch; do
  n=$(basename "$f"); z=$(printf '%s' "${n%%-*}" | tr -cd 'z' | wc -c)
  echo "$z $n"
done | sort -n | tail -6

echo
echo "== 6. 补丁重放顺序（build 脚本怎么排的）=="
grep -rn "patches/umi-xnu\|umi-xnu" "$X/scripts"/*.sh 2>/dev/null | head -10
echo done
