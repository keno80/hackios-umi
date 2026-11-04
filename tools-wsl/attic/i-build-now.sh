#!/bin/bash
# 直查本轮 trace 构建的真实状态：latest 指针、pid、日志尾部、产物时间戳。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/i-build-now.txt
: > "$OUT"
exec >>"$OUT" 2>&1
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
echo "== latest 指针 =="
cat "$LOGD/kernel-trace-latest.txt"
echo "== pid 文件 =="
cat "$LOGD/kernel-trace.pid" 2>/dev/null
P=$(cat "$LOGD/kernel-trace.pid" 2>/dev/null)
if [ -n "$P" ] && kill -0 "$P" 2>/dev/null; then echo "ALIVE"; else echo "DEAD"; fi
echo "== 最近的 3 个 trace 日志 =="
ls -lat "$LOGD"/kernel-trace-*.log 2>/dev/null | head -3
echo "== 最新日志尾部 25 行 =="
L=$(cat "$LOGD/kernel-trace-latest.txt")
tail -25 "$L" 2>/dev/null
echo "== 产物时间戳 =="
ls -la /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/*.macho 2>/dev/null
echo "== 工作树里探针是否已重放 =="
grep -c "boot_progress_stage(umi_msg)" \
  /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work/bsd/kern/bsd_init.c \
  /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work/bsd/vfs/vfs_subr.c 2>/dev/null
echo "== ext4 补丁目录 =="
ls -la /home/unixnu/code/UniXNU-umi/patches/umi-xnu/ | tail -4
echo done
