#!/bin/bash
# 把 tools-wsl 下所有 *.sh 同步成 /usr/local/bin/<去掉.sh> 命令
set -u
src=/mnt/e/Code/HackIos/tools-wsl
for f in "$src"/*.sh; do
  base=$(basename "$f" .sh)
  [ "$base" = "sync-helpers" ] && continue
  tr -d '\r' < "$f" > "/usr/local/bin/$base"
  chmod 755 "/usr/local/bin/$base"
done
echo "已同步：$(ls /usr/local/bin | grep -E 'progress|dashboard|rawlog|run-|classify|unixnu-env|wait-and-build' | tr '\n' ' ')"
/usr/local/bin/progress
