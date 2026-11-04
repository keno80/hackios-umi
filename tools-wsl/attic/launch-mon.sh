#!/bin/bash
# 在 WSL 内部起一个终端窗口（WSLg → 显示在 Windows 桌面），里面跑 ANSI 监控
command -v xterm >/dev/null 2>&1 || {
  echo "== 安装 xterm（WSLg 终端）"
  apt-get install -y --no-install-recommends xterm > /tmp/xterm-install.log 2>&1 || {
    echo "APT FAIL"; tail -6 /tmp/xterm-install.log; }
}
command -v xterm >/dev/null 2>&1 || { echo "没有可用 xterm"; exit 1; }
export DISPLAY=:0
export TERM=xterm-256color
M=/home/unixnu/code/umi-work-pin/out/monitor-win.log
setsid nohup xterm -display :0 -title "UniXNU · umi 实时监控" \
  -geometry 132x48 -fa "DejaVu Sans Mono:size=11" \
  -bg "#0b0f14" -fg "#c8d3de" -cr "#4fd1a5" -tn xterm-256color \
  -e uefi-mon > "$M" 2>&1 < /dev/null &
sleep 3
echo "== xterm 进程"
pgrep -fa "xterm -display" | head -2
echo "== monitor 进程"
pgrep -fa "umi-mon.py" | head -2
echo "== 窗口日志"
awk 'length($0)<200' "$M" 2>/dev/null | tail -5
echo DONE
