#!/bin/bash
exec > /mnt/e/Code/HackIos/out/probes/udif-diff.txt 2>&1
echo "== pinned tree: sources/UniXNU/scripts/unixnu/userdata.py =="
grep -n -E "platform|hdiutil|udif|def " /home/unixnu/code/umi-work-pin/sources/UniXNU/scripts/unixnu/userdata.py
echo "== md5 across trees =="
md5sum /home/unixnu/code/umi-work-pin/sources/UniXNU/scripts/unixnu/userdata.py \
       /home/unixnu/code/umi-work/sources/UniXNU/scripts/unixnu/userdata.py \
       /home/unixnu/code/UniXNU-main/scripts/unixnu/userdata.py
echo "== pinned tree has udif.py? =="
ls -la /home/unixnu/code/umi-work-pin/sources/UniXNU/scripts/unixnu/udif.py 2>&1
echo "== pinned tree git =="
cd /home/unixnu/code/umi-work-pin/sources/UniXNU && git log --oneline -1 && git status --short | head -20
