#!/bin/bash
# 确认 boot_progress_stage 的调用点没有被 boot_progress_active() 一类的门再挡一层。
set -u
OUT=/mnt/e/Code/HackIos/out/f-active.txt
: > "$OUT"
exec >>"$OUT" 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
echo "== active/init/start 在四个文件里的用法 =="
grep -rn 'boot_progress_active\|boot_progress_init\|boot_progress_start' \
  $X/bsd/kern/bsd_init.c $X/bsd/kern/kern_exec.c $X/osfmk/kern/startup.c \
  $X/osfmk/arm/arm_init.c $X/osfmk/arm64/sleh.c 2>&1
echo
echo "== bsd_init.c 的 stage 调用点行号 =="
grep -n 'boot_progress_stage' $X/bsd/kern/bsd_init.c
echo
echo "== kern_exec.c 的 stage 调用点行号 =="
grep -n 'boot_progress_stage' $X/bsd/kern/kern_exec.c
echo
echo "== kern_exec.c 里 XNU_BOOT_PROGRESS 的 #if 块 =="
grep -n 'XNU_BOOT_PROGRESS' $X/bsd/kern/kern_exec.c
echo
echo "== 每个 stage 调用点的实际文本 =="
grep -hn 'boot_progress_stage' $X/bsd/kern/bsd_init.c $X/bsd/kern/kern_exec.c \
  $X/osfmk/arm/arm_init.c $X/osfmk/kern/startup.c
