#!/bin/bash
exec > /mnt/e/Code/HackIos/out/probes/root-stage2.txt 2>&1
echo "== restore bind =="
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/ensure-dev-bind.sh > /tmp/ensure-dev-bind.sh
bash /tmp/ensure-dev-bind.sh
echo "-- devices/umi now --"
ls /home/unixnu/code/umi-work-pin/devices/umi | head -20

echo "== README userdata/ipsw blocks =="
grep -n -B3 -A12 -E "userdata|ipsw" /home/unixnu/code/UniXNU-umi/README.zh-CN.md | head -120

echo "== unixnu CLI + ipsw.py =="
ls /home/unixnu/code/umi-work-pin/unixnu /home/unixnu/code/umi-work-pin/sources/UniXNU/scripts/unixnu/ 2>&1 | head -40
echo "-- ipsw.py: cache dir + download --"
grep -n -E "def |cache|urlopen|Range|download|SHA|partial" /home/unixnu/code/umi-work-pin/sources/UniXNU/scripts/unixnu/ipsw.py | head -60
