#!/bin/bash
# watch 用的实时仪表盘：指标 + 阶段 + 最近日志
set -u
LATEST=/home/unixnu/code/UniXNU-main/out/unixnu-logs/latest.txt
LOG=$(cat "$LATEST" 2>/dev/null)
echo "时间 $(date '+%H:%M:%S')  |  UniXNU on WSL2  |  按 Ctrl-C 退出，日志文件不受影响"
if [ -z "${LOG:-}" ] || [ ! -f "$LOG" ]; then
  echo "当前没有构建日志。运行 run-toolchain 或 run-kernel 后这里会滚动。"
  exit 0
fi
/usr/local/bin/progress "$LOG"
phase=$(grep -oE 'llvm-project|cctools-port|swift-corelibs-libdispatch|bootstrap_cmds|iig-port|lzfse|build-xnu-4k-baseline|corecrypto|libpthread|ArmDTPlatform|ArmCpu|kernel' "$LOG" 2>/dev/null | tail -1)
echo "当前关键词=$phase"
echo "===== 最近 25 行（$LOG） ====="
tail -25 "$LOG"
