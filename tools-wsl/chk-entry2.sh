#!/bin/bash
exec > /mnt/e/Code/HackIos/out/root-entry2.txt 2>&1
echo "== cli.py tail =="
tail -30 /home/unixnu/code/umi-work-pin/sources/UniXNU/scripts/unixnu/cli.py
echo "== candidates =="
ls -la /home/unixnu/code/umi-work-pin/sources/UniXNU/ | head -20
find /home/unixnu/code/umi-work-pin/sources/UniXNU -maxdepth 2 -name "unixnu*" -not -path "*/.git/*" | head
echo "== how our tools run it =="
grep -rn "cli" /home/unixnu/code/umi-work-pin/tools/build_umi_xnu.py | head -10
sed -n '85,110p' /home/unixnu/code/umi-work-pin/tools/build_umi_xnu.py
echo "== docs invocation =="
grep -rn "scripts/unixnu\|python3 .*cli\|./unixnu" /home/unixnu/code/umi-work-pin/sources/UniXNU/docs/zh/porting/*.md | head -15
