#!/bin/bash
# 两道可行性闸门：(1) Linux 分支能否解 DMG 原始盘；(2) devices/umi 绑定是否还在
set -u
OUT=/mnt/e/Code/HackIos/out/probes/linux-udif.txt
U=/home/unixnu/code/UniXNU-main
W=/home/unixnu/code/umi-work-pin
{
  echo "== userdata.py 60-115（看 Darwin 判定）"
  sed -n '60,115p' $U/scripts/unixnu/userdata.py
  echo
  echo "== udif.py 存在与接口"
  ls -l $U/scripts/unixnu/udif.py 2>&1
  grep -n 'def \|class ' $U/scripts/unixnu/udif.py 2>/dev/null | head -15
  echo
  echo "== devices/umi 现状"
  ls -la $W/devices/umi | head -5
  echo "-- 设备仓候选 --"
  for d in /home/unixnu/code/UniXNU-umi /home/unixnu/code/UniXNU-sheng; do
    echo "$d:"; ls -1 $d 2>/dev/null | head -8; echo
  done
  echo "== 绑定/挂载痕迹"
  mount | grep -i 'umi\|work-pin' | head -5
  echo
  echo "== 内核构建当时怎么拿到 devices/umi"
  grep -rn 'devices/umi' $W/tools/*.sh 2>/dev/null | head -6
  grep -rn 'devices/umi\|bind' /usr/local/bin/*umi* 2>/dev/null | head -10
} > "$OUT" 2>&1
echo WROTE
