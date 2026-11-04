#!/bin/bash
# M 步构建状态：pid 存活、日志尾、23z 是否已重放进工作树。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/m15-walk-build.txt
: > "$OUT"
exec >>"$OUT" 2>&1
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
WS=/home/unixnu/code/umi-work-pin
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== latest / pid =="
cat "$LOGD/kernel-walk-latest.txt"
P=$(cat "$LOGD/kernel-walk.pid" 2>/dev/null); echo "pid=$P"
if [ -n "$P" ] && kill -0 "$P" 2>/dev/null; then echo ALIVE; else echo DEAD; fi

echo
echo "== 日志尾（去 ANSI）=="
L=$(cat "$LOGD/kernel-walk-latest.txt")
sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' "$L" 2>/dev/null | tail -20

echo
echo "== 23z 是否已重放进工作树 =="
grep -c 'umi_el0_unix_seen\|umi_el0_out_seen' "$X/osfmk/arm64/sleh.c" 2>/dev/null
grep -n 'EL0 IN\|EL0 OUT' "$X/osfmk/arm64/sleh.c" 2>/dev/null | head

echo
echo "== ext4 补丁目录尾部 =="
ls /home/unixnu/code/UniXNU-umi/patches/umi-xnu/ | grep '^z' | sort | tail -3

echo
echo "== 产物 =="
ls -la $WS/out/umi-xnu/umi/kernel/*.macho 2>/dev/null
echo "== done $(date -u +%FT%TZ)"
