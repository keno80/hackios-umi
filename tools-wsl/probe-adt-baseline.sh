#!/bin/bash
# adt 基线是怎么产出的、有没有 ramdisk 开关的通路
W=/home/unixnu/code/umi-work-pin
echo "== 谁写 adt-baseline.json =="
grep -rn "adt-baseline" $W/tools $W/devices/umi --include=*.py 2>/dev/null | head -12
echo
echo "== 谁调 make-umi-adt.py =="
grep -rn "make-umi-adt" $W/tools $W/devices/umi --include=*.py --include=*.toml --include=*.sh 2>/dev/null | head -12
echo
echo "== build_umi_xnu.py 的 stage 与 adt 相关参数 =="
grep -nE "add_argument|stage|adt" $W/tools/build_umi_xnu.py | grep -iE "adt|stage" | head -25
