#!/bin/bash
# 路A 完成态：产物、收据关键字段、下一步 QEMU 命令所需的输入是否齐
W=/home/unixnu/code/umi-work-pin
K=$W/out/umi-xnu/umi/kernel
LOG=$(cat /home/unixnu/code/UniXNU-main/out/unixnu-logs/kernel-pin-latest.txt)
echo "=== 主日志（阶段+结论）==="
cat "$LOG"
echo
echo "=== 内核产物 ==="
ls -l --time-style=+%H:%M:%S "$K" 2>&1
echo "=== 收据 ==="
for f in "$W"/out/umi-xnu/umi/*source-build*.json "$K"/*source-build*.json; do
  [ -f "$f" ] && { echo "-- $f"; python3 -c "
import json,sys
r=json.load(open(sys.argv[1]))
for k,v in r.items():
    s=json.dumps(v)
    print(f'{k}: {s[:220]}')
" "$f"; }
done
echo "=== QEMU 输入 ==="
FW=$W/out/umi-qemu/firmware
ls -l "$FW/Build/Out/AARCH64-DEBUG/UniXNU.efi" "$FW/build/DarwinBoot/DEBUG_CLANGPDB/AARCH64/DarwinBoot.efi" 2>&1
echo "adt 脚本=$(ls $W/sources/UniXNU/scripts/qemu-entry/make-dt.py 2>/dev/null)"
echo "qemu=$(qemu-system-aarch64 --version | head -1)"
