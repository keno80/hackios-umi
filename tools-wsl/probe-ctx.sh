#!/bin/bash
cd /home/unixnu/code/umi-work-pin/sources/UniXNU/scripts/unixnu || exit 1
echo "=== prepare() 全文 ==="
sed -n '70,95p' cli.py
echo
echo "=== config.py 里的 ctx 字段 ==="
grep -n "class Ctx" -A 45 config.py | head -60
echo
echo "=== main() 尾部 ==="
awk '/^def main/,0' cli.py | head -45
