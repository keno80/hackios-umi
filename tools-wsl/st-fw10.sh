#!/bin/bash
LOG=/home/unixnu/code/umi-work-pin/out/umi-fw/run-10/firmware.log
echo "=== 进度（行数 / 最新动作）==="
wc -l "$LOG" 2>/dev/null
tail -4 "$LOG" 2>/dev/null
echo "=== 错误 ==="
grep -n -iE "error:|error [0-9A-F]{4}|Failed" "$LOG" 2>/dev/null | head -8
echo "=== 进程 ==="
pgrep -af "uefi-fw-build" | head -3
echo "=== FD ==="
ls -la /home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd 2>/dev/null
echo "=== UmiBootLog.efi ==="
find /home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/AARCH64 -name "UmiBootLog.efi" 2>/dev/null | head -3
