#!/bin/bash
# 全量单测（保留完整输出）+ 分类统计
set -u
source /usr/local/bin/unixnu-env
WS=/home/unixnu/code/umi-work
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
ts=$(date +%Y%m%d-%H%M%S)
LOG=$LOGD/unittest-$ts.log
echo "$LOG" > "$LOGD/unittest-latest.txt"
cd "$WS" || exit 1
python3 -m unittest discover -s tests -v > "$LOG" 2>&1
echo "exit=$?" >> "$LOG"
echo "LOG $LOG"
grep -E '^(ERROR|FAIL): ' "$LOG" | sed 's/ (.*//' | sort | uniq -c
echo "--- 统计 ---"
tail -5 "$LOG"
echo "--- 根因抽样 ---"
grep -oE "(FileNotFoundError|CalledProcessError|error: unknown argument|unsupported|No such file or directory)[^$]{0,90}" "$LOG" | sort | uniq -c | sort -rn | head -12
