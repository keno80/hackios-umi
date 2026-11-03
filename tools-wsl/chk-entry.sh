#!/bin/bash
exec > /mnt/e/Code/HackIos/out/root-entry.txt 2>&1
echo "== how tools invoke upstream CLI =="
grep -n -E "upstream_parser|unixnu\.py|__main__|subprocess|sys.path" /home/unixnu/code/umi-work-pin/tools/prepare_umi_root.py | head -20
echo "--"
grep -n -E "upstream_parser|unixnu|kernel\" , \"build|argv" /home/unixnu/code/umi-work-pin/tools/build_umi_xnu.py | head -25
echo "== entrypoint files =="
ls /home/unixnu/code/umi-work-pin/sources/UniXNU/scripts/ | grep -E "^(unixnu|cli)" 
ls -la /home/unixnu/code/umi-work-pin/sources/UniXNU/scripts/unixnu/__main__.py 2>&1
head -40 /home/unixnu/code/umi-work-pin/sources/UniXNU/scripts/unixnu/cli.py
echo "== prepare_umi_root main head =="
sed -n '70,100p' /home/unixnu/code/umi-work-pin/tools/prepare_umi_root.py
