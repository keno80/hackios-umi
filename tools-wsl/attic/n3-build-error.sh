#!/bin/bash
# 构建失败：抓 kernel.log 的第一条 error 与上下文。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/n3-build-error.txt
: > "$OUT"
exec >>"$OUT" 2>&1
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
L=$(cat "$LOGD/kernel-walk-latest.txt" 2>/dev/null)
echo "MAIN-LOG=$L"
KL=$(ls -t /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/logs/*/kernel.log 2>/dev/null | head -1)
echo "KERNEL-LOG=$KL"
echo
echo "== 主日志尾 30 行 =="
sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' "$L" 2>/dev/null | tail -30
echo
echo "== kernel.log 里所有 error 行 =="
sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' "$KL" 2>/dev/null | grep -n 'error:\|fatal error:\|FAILED:' | head -20
echo
echo "== 第一条 error 前后 25 行 =="
sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' "$KL" 2>/dev/null | grep -n 'error:' | head -1
N=$(sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' "$KL" | grep -n 'error:' | head -1 | cut -d: -f1)
if [ -n "$N" ]; then
  S=$((N>25?N-25:1)); E=$((N+25))
  sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' "$KL" | sed -n "${S},${E}p" | nl -ba -v"$S"
fi
echo
echo "== 谁在编这个文件（找 compdb/命令行片段）=="
sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' "$KL" 2>/dev/null | grep -o '[a-z_/]*\.c' | sort -u | tail -12
echo "== done $(date -u +%FT%TZ)"
