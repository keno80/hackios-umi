#!/bin/bash
cd /home/unixnu/code/umi-work-pin || exit 1
echo "=== make_umi_payload.py 概览 ==="
wc -l tools/make_umi_payload.py
grep -n "def \|diagnostic\|argparse\|add_argument\|ramoops\|trace" tools/make_umi_payload.py | head -40
echo
echo "=== ramoops 地址/格式 ==="
grep -rn "RAMOOPS\|ramoops" sources/UniXNU/drivers/DarwinBoot/ devices/umi/package/boot-progress/*.h tools/*.py 2>/dev/null | head -25
