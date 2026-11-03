#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
S=$WS/out/tui-state
NAME=pack-menu
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/pack-menu.sh > /tmp/pack-menu.sh
chmod +x /tmp/pack-menu.sh
LOG=$WS/out/umi-fw/pack-menu.log
mkdir -p "$WS/out/umi-fw"
nohup bash /tmp/pack-menu.sh > /dev/null 2>&1 &
PID=$!
{
  echo "PHASE=打菜单镜像"
  echo "RUN=1"
  echo "TOOL=unixnu bootimg"
  echo "LOG=$LOG"
  echo "START_TS=$(date +%s)"
  echo "NOTE1=FD 6ef6a279 + 实机 running.dtb（绕开 dtbo_idx=11 硬编码）"
  echo "NOTE2=只打包，不碰手机"
  echo "TASK1=run|#10 打 umi-uefi-menu.img"
  echo "TASK2=block|上机 fastboot boot（等确认）"
  echo "TASK3=block|#15 需 Apple 参考件"
  echo "PID=$PID"
} > "$S"
echo "started pid=$PID"
