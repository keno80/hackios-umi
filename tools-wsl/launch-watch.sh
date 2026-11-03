#!/bin/bash
# 同步全部 helper，然后后台起 A/B 完成监视器
set -u
L=/home/unixnu/code/UniXNU-main/out/unixnu-logs
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/sync-helpers.sh > /tmp/sh.sh
bash /tmp/sh.sh > /tmp/sh.out 2>&1 || true
ls -l /usr/local/bin/watch-ab /usr/local/bin/ab-status 2>&1 | tail -2
old=$(cat "$L/watch.pid" 2>/dev/null || true)
[ -n "${old:-}" ] && kill -0 "$old" 2>/dev/null && echo "已有监视器 pid=$old" && exit 0
setsid nohup /usr/local/bin/watch-ab > "$L/watch-ab.out" 2>&1 < /dev/null &
echo $! > "$L/watch.pid"
sleep 2
echo "监视器 pid=$(cat "$L/watch.pid") $(kill -0 $(cat "$L/watch.pid") 2>/dev/null && echo 运行中 || echo 已退出)"
