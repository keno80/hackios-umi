#!/bin/bash
set -u
L=$(cat /home/unixnu/code/UniXNU-main/out/unixnu-logs/unittest-latest.txt)
echo "=== 7 个错误的模块与首行原因 ==="
grep -E '^(ERROR|FAIL): ' -A 12 "$L" | grep -E "^(ERROR|FAIL): |Error|error:|No such file|argument unused|FileNotFound|CalledProcess|subprocess" | head -40
echo
echo "=== 每个错误的关键行 ==="
awk '/^(ERROR|FAIL): /{name=$0; print "### " name; got=0} /Exception|Error:|error:|No such file|unused during/{if(name!=""&&!got){print "    " $0; got=1}}' "$L" | head -30
