#!/bin/bash
exec > /mnt/e/Code/HackIos/out/udif-diff2.txt 2>&1
P=/home/unixnu/code/umi-work-pin/sources/UniXNU/scripts/unixnu/userdata.py
M=/home/unixnu/code/UniXNU-main/scripts/unixnu/userdata.py
echo "== unified diff pinned -> main =="
diff -u "$P" "$M"
echo "RC=$?"
echo "== main header (imports) =="
sed -n '1,45p' "$M"
