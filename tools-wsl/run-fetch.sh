#!/bin/bash
# 后台拉取内核参考源码（网络密集，与 clang 构建并行）
set -u
source /usr/local/bin/unixnu-env
cd /home/unixnu/code/UniXNU-main || exit 1
LOGD=out/unixnu-logs
mkdir -p "$LOGD"
ts=$(date +%Y%m%d-%H%M%S)
LOG=$LOGD/fetch-$ts.log
echo "$LOG" > "$LOGD/fetch-latest.txt"
setsid nohup python3 -u unixnu fetch xnu libplatform libdispatch AvailabilityVersions \
  corecrypto-2023 libpthread xnu-driverkit xnu-trustcache > "$LOG" 2>&1 &
echo $! > "$LOGD/fetch.pid"
sleep 5
echo "RUNNING pid=$(cat "$LOGD/fetch.pid") LOG=$LOG"
tail -5 "$LOG"
