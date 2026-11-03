#!/bin/bash
cd /home/unixnu/code/umi-work-pin || exit 1
echo "=== config.py Context ==="
awk '/^class Context/,/^class [A-Za-z]/' sources/UniXNU/scripts/unixnu/config.py | head -55
echo
echo "=== umi_adt: hardware_path / load_hardware ==="
grep -n "def hardware_path" -A 8 devices/umi/scripts/umi_adt.py
grep -n "def load_hardware" -A 12 devices/umi/scripts/umi_adt.py
echo
echo "=== 硬件画像文件是否存在 ==="
grep -rn "hardware\b.*json\|HARDWARE" devices/umi/scripts/umi_adt.py | head -8
