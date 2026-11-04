#!/bin/bash
# 进度快照：out/chk-<name>.txt 由调用方重定向
NAME=${1:-run-02}
L=/home/unixnu/code/umi-work-pin/out/umi-fw/$NAME/firmware.log
R=/mnt/e/Code/HackIos/out/probes/uefi-fw-$NAME.txt
echo "== 构建进程: $(pgrep -fa 'build -p Platforms' | head -2)"
echo "== run 头部"; awk 'length($0)<300' "$R" 2>/dev/null | head -12
echo "== log 行数=$( [ -f "$L" ] && wc -l < "$L" || echo 0 ) 大小=$( [ -f "$L" ] && stat -c %s "$L" || echo 0 )"
echo "== 首次错误"; awk 'length($0)<300' "$L" 2>/dev/null | grep -n -m 12 -E "error:|ERROR|Error [0-9]|FAILED|case mismatch|No such file" | sed 's/^/  /'
echo "== log 末尾"; awk 'length($0)<300' "$L" 2>/dev/null | tail -12 | sed 's/^/  | /'
echo "== FD"; ls -l /home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd 2>/dev/null
echo DONE
