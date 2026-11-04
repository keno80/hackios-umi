#!/bin/bash
set -u
exec > /mnt/e/Code/HackIos/out/probes/t21-devbind2.txt 2>&1
WS=/home/unixnu/code/umi-work-pin
echo "== 1. ensure-dev-bind 定义在哪 =="
grep -rn "ensure-dev-bind\|ensure_dev_bind" /usr/local/bin/ $WS/tools/ 2>/dev/null | head -20

echo
echo "== 2. devices/umi 现状 =="
ls -la $WS/devices/ 2>&1 | head
echo "-- umi 里 --"
ls -la $WS/devices/umi 2>&1 | head -20
echo "-- 是否挂载点 --"
findmnt -T $WS/devices/umi 2>&1 | head

echo
echo "== 3. 报错原文出处 =="
grep -rn "是非空目录，停手" /usr/local/bin/ $WS/tools/ /mnt/e/Code/HackIos/tools-wsl/ 2>/dev/null | head -10
grep -rn "non-empty" /usr/local/bin/unixnu-env 2>/dev/null | head -5

echo
echo "== 4. unixnu-env 全文 =="
wc -l /usr/local/bin/unixnu-env 2>/dev/null
cat /usr/local/bin/unixnu-env 2>/dev/null

echo
echo "== 5. 上一次成功构建是怎么起的（walk 日志头） =="
L=$(cat /home/unixnu/code/UniXNU-main/out/unixnu-logs/kernel-walk-latest.txt 2>/dev/null)
echo "latest=$L"
head -20 "$L" 2>/dev/null | sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g'
