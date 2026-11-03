#!/bin/bash
# 实时跟随最新一份构建日志（原始输出，不刷新屏幕）
set -u
LATEST=/home/unixnu/code/UniXNU-main/out/unixnu-logs/latest.txt
LOG=$(cat "$LATEST" 2>/dev/null)
if [ -z "${LOG:-}" ] || [ ! -f "$LOG" ]; then
  echo "还没有日志文件；等 run-toolchain / run-kernel 启动后再进来。"
  sleep 30
  exit 0
fi
echo "跟随：$LOG"
exec tail -n +1 -F "$LOG"
