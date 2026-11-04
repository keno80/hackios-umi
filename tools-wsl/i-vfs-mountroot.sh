#!/bin/bash
# 读 vfs_mountroot 的实现与失败分支；确认 systm.h 里 snprintf 是否可用。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/i-vfs-mountroot.txt
: > "$OUT"
exec >>"$OUT" 2>&1

X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== vfs_subr.c 1150-1420 =="
grep -n "" "$X/bsd/vfs/vfs_subr.c" | sed -n '1150,1420p'

echo
echo "== systm.h 里的 printf/snprintf 声明 =="
grep -n "printf" "$X/bsd/sys/systm.h" | head -20

echo
echo "== bsd_init.c 的 include 头部 =="
sed -n '1,120p' "$X/bsd/kern/bsd_init.c" | grep -n "#include" 

echo
echo "== vfs_subr.c 的 include 头部 =="
grep -n "#include" "$X/bsd/vfs/vfs_subr.c" | head -50
echo done
