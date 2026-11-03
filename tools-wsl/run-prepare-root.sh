#!/bin/bash
exec > /mnt/e/Code/HackIos/out/prepare-root-launch.txt 2>&1
cd /home/unixnu/code/umi-work-pin || exit 1
echo "== port prepare_umi_root.py =="
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/port-pin-prep-root.py > /tmp/port-pin-prep-root.py
python3 /tmp/port-pin-prep-root.py
echo "PORT_RC=$?"
echo "== import smoke =="
python3 -c "
import sys; sys.path.insert(0,'sources/UniXNU/scripts')
from unixnu import userdata, udif, util
print('udif ok, lzfse=', util.lzfse())
"
echo "== 旧状态 =="
ls -la out/umi-xnu/umi/userdata 2>&1 | head
echo "== launch =="
mkdir -p out/umi-xnu
LOG=/home/unixnu/code/umi-work-pin/out/umi-xnu/userdata-prepare.log
setsid nohup python3 tools/prepare_umi_root.py > "$LOG" 2>&1 < /dev/null &
echo "PID=$!  LOG=$LOG"
sleep 30
echo "== 30s 后 =="
ps -o pid,etime,rss,cmd -p $(pgrep -f 'prepare_umi_root[.]py' | head -1) 2>&1
tail -15 "$LOG"
echo "== 缓存目录 =="
ls -la out/umi-xnu/ipsw/21H461 2>&1 | head
