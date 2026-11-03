#!/bin/bash
# umi 板级配置里是否声明了 [ipsw] 与 [userdata] windows；以及取 IPSW 的入口
set -u
W=/home/unixnu/code/umi-work-pin
OUT=/mnt/e/Code/HackIos/out/board-ipsw.txt
{
  echo "== devices/umi 目录"
  ls -1 $W/devices/umi/ 2>&1 | head -20
  echo
  echo "== 含 ipsw/userdata 的文件"
  grep -rln 'ipsw\|userdata' $W/devices/umi/ 2>/dev/null | head -10
  echo
  echo "== [ipsw] 段"
  awk '/^\[ipsw/,/^\[/{print}' $W/devices/umi/*.toml 2>/dev/null | head -30
  echo
  echo "== [userdata] 段"
  grep -n -A28 '^\[userdata\]' $W/devices/umi/*.toml 2>/dev/null | head -40
  echo
  echo "== unixnu ipsw 子命令"
  ls $W/sources/UniXNU/scripts/ 2>/dev/null | head -5
  grep -rn 'ipsw fetch\|def fetch\|UNIXNU_IPSW' $W/sources/UniXNU/scripts/unixnu/ipsw.py 2>/dev/null | head -12
  echo
  echo "== 磁盘空间"
  df -h /home/unixnu | tail -1
} > "$OUT" 2>&1
echo WROTE
