#!/bin/bash
set -uo pipefail
source /usr/local/bin/unixnu-env 2>/dev/null || true
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
mkdir -p "$LOGD"
NAME=${1:-run-07-screen}
LOG="$LOGD/qemu-$NAME.launch.log"
cd /mnt/e/Code/HackIos || exit 1
setsid nohup bash tools-wsl/run-umi-qemu.sh "$NAME" \
  --args "-v keepsyms=1 kt_fixed_zones=120" --capture-screen --timeout 300 \
  > "$LOG" 2>&1 &
echo "pid=$! LOG=$LOG"
