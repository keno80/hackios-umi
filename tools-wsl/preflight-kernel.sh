#!/bin/bash
cd /home/unixnu/code/umi-work-pin || exit 1
echo "=== DarwinBootPkg ==="
ls sources/UniXNU/drivers/DarwinBoot/DarwinBootPkg 2>&1 | head -20
echo "=== PackedRamdisk.h sha ==="
f=devices/umi/package/darwinboot/PackedRamdisk.h
if [ -f "$f" ]; then sha256sum "$f"; ls -la "$f"; else echo "MISSING: $f"; find devices -name "PackedRamdisk*"; fi
echo "=== unixnu CLI 入口 ==="
cat sources/UniXNU/unixnu
echo "=== scripts/unixnu 模块 ==="
ls sources/UniXNU/scripts/unixnu/
echo "=== payload 参数注册 ==="
grep -rn "unique.chip.id\|'payload'\|\"payload\"\|add_argument" sources/UniXNU/scripts/unixnu/cli.py 2>/dev/null | head -40
