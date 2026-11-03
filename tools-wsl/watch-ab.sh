#!/bin/bash
# 起一个后台监视：A/B 两条内核构建都退出后写 ab-done.flag，并把摘要写进文件
set -u
L=/home/unixnu/code/UniXNU-main/out/unixnu-logs
deadline=$(( $(date +%s) + 6 * 3600 ))
while [ "$(date +%s)" -lt "$deadline" ]; do
  mp=$(cat "$L/kernel-main.pid" 2>/dev/null || true)
  pp=$(cat "$L/kernel-pin.pid" 2>/dev/null || true)
  if [ -n "$mp" ] && [ -n "$pp" ] \
     && ! kill -0 "$mp" 2>/dev/null && ! kill -0 "$pp" 2>/dev/null; then
    sleep 5
    ab-status > "$L/ab-final.txt" 2>&1
    touch "$L/ab-done.flag"
    echo "两条构建都已结束，摘要写入 $L/ab-final.txt"
    exit 0
  fi
  sleep 30
done
echo "监视超时（6 小时）"
exit 1
