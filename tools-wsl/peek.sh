#!/bin/bash
# 最近日志尾部：peek [行数]，默认读 latest.txt 指向的日志
set -u
L=/home/unixnu/code/UniXNU-main/out/unixnu-logs
N=${1:-12}
F=${2:-}
[ -z "$F" ] && F=$(cat "$L/latest.txt" 2>/dev/null)
[ -f "$F" ] || { echo "没有日志：$F"; exit 0; }
echo "===== $F ====="
tail -n "$N" "$F"
