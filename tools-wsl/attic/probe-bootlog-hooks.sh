#!/bin/bash
# 坐实「PE_lockdown_iokit 是不是 kernel_bootstrap_log 的最后一条」+ 画屏补丁到底钩了谁
set -u
OUT=/mnt/e/Code/HackIos/out/probes/d-pe-lockdown3.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
P=/home/unixnu/code/umi-work-pin/devices/umi/patches/umi-xnu

say "== 1. startup.c 里 kernel_bootstrap_log 的全部调用 =="
grep -n "kernel_bootstrap_log(" "$T/osfmk/kern/startup.c" >> "$OUT"
say "-- 其中行号 > 844 的 --"
awk 'NR>844 && /kernel_bootstrap_log\(/ {print NR": "$0}' "$T/osfmk/kern/startup.c" >> "$OUT"
say
say "== 2. bsd_init.c 里走的是哪种日志 =="
grep -c "kernel_bootstrap_log(" "$T/bsd/kern/bsd_init.c" >> "$OUT"
grep -n "kernel_bootaudio_log\|printf(\" BSD root\|klogprintf\|kernel_bootstrap_thread_log" "$T/bsd/kern/bsd_init.c" | head -12 >> "$OUT"
say "-- bsd_init 里 mountroot 前后的日志行 --"
grep -n "vfs_mountroot\|mountroot\|root device" "$T/bsd/kern/bsd_init.c" | head -12 >> "$OUT"
say
say "== 3. 上屏补丁文件与钩到的符号 =="
ls -la "$P" >> "$OUT"
for f in "$P"/*screen*.patch "$P"/*bootlog*.patch; do
  [ -f "$f" ] || continue
  say "-- $f --"
  grep -n "^+++\|UMI \|umi_mark\|umi_paint\|kernel_bootstrap_log" "$f" | head -25 >> "$OUT"
done
say done
