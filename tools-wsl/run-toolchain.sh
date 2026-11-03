#!/bin/bash
# 启动 Linux 工具链构建（定制 clang 等）。日志带时间戳，latest.txt 指向最新一份。
set -u
source /usr/local/bin/unixnu-env
WS=/home/unixnu/code/UniXNU-main
LOGD=$WS/out/unixnu-logs
mkdir -p "$LOGD"
PIDF=$LOGD/toolchain.pid
if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
  echo "已在运行 pid=$(cat "$PIDF") 日志=$(cat "$LOGD/latest.txt" 2>/dev/null)"
  exit 0
fi
ts=$(date +%Y%m%d-%H%M%S)
LOG=$LOGD/toolchain-$ts.log
echo "$LOG" > "$LOGD/latest.txt"
cd "$WS" || exit 1
{ echo "=== toolchain build start $(date -Is) | prefix=/opt/unixnu-linux jobs=8 ==="; } > "$LOG"
TMPDIR=/var/tmp setsid nohup python3 -u scripts/linux/setup-toolchain.py \
  --package-manager none -j 8 /opt/unixnu-linux >> "$LOG" 2>&1 &
echo $! > "$PIDF"
sleep 3
pid=$(cat "$PIDF")
if kill -0 "$pid" 2>/dev/null; then
  echo "RUNNING pid=$pid"
  echo "LOG $LOG"
else
  echo "FAILED pid=$pid"; tail -20 "$LOG"
fi
