#!/bin/bash
set -u
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
# 先装环境脚本，后面的启动脚本要 source 它
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/unixnu-env.sh > /usr/local/bin/unixnu-env
chmod 755 /usr/local/bin/unixnu-env
for f in run-toolchain.sh progress.sh dashboard.sh rawlog.sh run-fetch.sh run-hostcheck.sh; do
  base=$(basename "$f" .sh)
  tr -d '\r' < "/mnt/e/Code/HackIos/tools-wsl/$f" > "/usr/local/bin/$base"
  chmod 755 "/usr/local/bin/$base"
done
echo "helpers installed"
# 停掉卡住的实例并清理半截源码目录
for p in "$LOGD/toolchain.pid" "$LOGD/fetch.pid" /home/unixnu/logs/toolchain.pid; do
  pid=$(cat "$p" 2>/dev/null || true)
  if [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null; then
    pkill -P "$pid" 2>/dev/null || true
    kill "$pid" 2>/dev/null || true
    echo "stopped pid=$pid ($p)"
  fi
done
pkill -f 'git-remote-https https://github.com/llvm' 2>/dev/null && echo "killed stalled llvm git-remote"
rm -rf /var/tmp/unixnu-toolchain-* /var/tmp/unixnu-host-check-*
rm -f "$LOGD/toolchain.pid" "$LOGD/fetch.pid"
# 代理自检
gw=$(ip route | awk '/^default/ {print $3; exit}')
echo "gateway=$gw  github直连=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 https://github.com 2>/dev/null)"
echo "github走代理=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 -x http://$gw:8090 https://github.com)"
/usr/local/bin/run-toolchain
/usr/local/bin/run-fetch
