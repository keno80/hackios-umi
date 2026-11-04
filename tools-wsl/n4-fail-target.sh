#!/bin/bash
# 精确定位这次构建失败的那条编译目标与它的 error 行。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/n4-fail-target.txt
: > "$OUT"
exec >>"$OUT" 2>&1
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
L=$(cat "$LOGD/kernel-walk-latest.txt")
KL=$(ls -t /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/logs/*/kernel.log | head -1)
CLEAN=$(mktemp)
sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' "$KL" > "$CLEAN"
echo "MAIN=$L"
echo "KERNEL=$KL"

echo
echo "== 1. ninja 的 FAILED 目标 =="
grep -a 'FAILED:' "$CLEAN" | head -10
echo "FAILED 计数=$(grep -ac 'FAILED:' "$CLEAN")"

echo
echo "== 2. 真正的 error:（带文件名:行:列: error:）=="
grep -aoE '[A-Za-z0-9_./-]+\.(c|h|S|cpp):[0-9]+:[0-9]+: (fatal )?error: .*' "$CLEAN" | sort -u | head -20

echo
echo "== 3. 我改过的两个文件里有没有命中 =="
grep -a 'kern_fork\.c\|kern_exit\.c' "$CLEAN" | grep -a 'error\|warning: implicit\|FAILED' | head -20

echo
echo "== 4. 主日志尾 25 行 =="
sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' "$L" | tail -25

echo
echo "== 5. clean 日志尾 60 行 =="
tail -60 "$CLEAN"
rm -f "$CLEAN"
echo "== done $(date -u +%FT%TZ)"
