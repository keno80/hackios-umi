#!/bin/bash
exec > /mnt/e/Code/HackIos/out/root-stage3.txt 2>&1
echo "== bind =="
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/ensure-dev-bind.sh > /tmp/ensure-dev-bind.sh
bash /tmp/ensure-dev-bind.sh
echo "-- devices/umi --"; ls /home/unixnu/code/umi-work-pin/devices/umi | head

echo "== prepare_umi_root.py flags =="
grep -n -E "add_argument|def main|dry|SystemExit|__main__" /home/unixnu/code/umi-work-pin/tools/prepare_umi_root.py | head -40

echo "== cli.py userdata/dry =="
grep -n -E "userdata|dry" /home/unixnu/code/umi-work-pin/sources/UniXNU/scripts/unixnu/cli.py | head -30

echo "== upstream entry points =="
ls /home/unixnu/code/umi-work-pin/sources/UniXNU/scripts/ | head -20
grep -rn "def main" /home/unixnu/code/umi-work-pin/sources/UniXNU/scripts/unixnu.py 2>/dev/null | head
