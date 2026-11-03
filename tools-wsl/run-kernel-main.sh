#!/bin/bash
# 路 B：上游 main + reAAAq 的 umi 设备仓，只出源码内核（--skip-prelink，不碰设备）
set -u
source /usr/local/bin/unixnu-env
MAIN=/home/unixnu/code/UniXNU-main
LOGD=$MAIN/out/unixnu-logs
mkdir -p "$LOGD"
ts=$(date +%Y%m%d-%H%M%S)
LOG=$LOGD/kernel-main-$ts.log
echo "$LOG" > "$LOGD/kernel-main-latest.txt"
echo "$LOG" > "$LOGD/latest.txt"
cd "$MAIN" || exit 1
setsid nohup python3 -u unixnu build kernel --skip-prelink -D /home/unixnu/code/UniXNU-umi -j 5 > "$LOG" 2>&1 &
echo $! > "$LOGD/kernel-main.pid"
sleep 10
pid=$(cat "$LOGD/kernel-main.pid")
if kill -0 "$pid" 2>/dev/null; then
  echo "路B 运行中 pid=$pid LOG=$LOG"
else
  echo "路B 立即退出，最后 25 行："
  tail -25 "$LOG"
fi
