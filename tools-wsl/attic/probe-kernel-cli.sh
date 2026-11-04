#!/bin/bash
cd /home/unixnu/code/umi-work-pin || exit 1
echo "=== cli.py payload 分支 ==="
sed -n '100,175p' sources/UniXNU/scripts/unixnu/cli.py
echo
echo "=== unique_chip_id 语义 ==="
grep -rn "unique_chip_id" sources/UniXNU/scripts/ devices/umi/scripts/ 2>/dev/null | grep -v Binary | head -20
echo
echo "=== umi_adt 里怎么用 ==="
grep -rn "unique_chip_id\|IOPlatformUUID\|platform-uuid" devices/umi/scripts/umi_adt.py 2>/dev/null | head -20 || find devices -name "umi_adt*" | head
