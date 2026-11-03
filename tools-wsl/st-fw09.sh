#!/bin/bash
LOG=/home/unixnu/code/umi-work-pin/out/umi-fw/run-09/firmware.log
echo "=== 文件 ==="
ls -la "$LOG" 2>&1 | head -3
ls -la /home/unixnu/code/umi-work-pin/out/umi-fw/run-09/ 2>/dev/null | head -10
echo "=== 头部 12 行 ==="
head -12 "$LOG" 2>/dev/null
echo "=== 关键字 ==="
grep -n -iE "error|fail|fatal|case mismatch|Build result|total time" "$LOG" 2>/dev/null | head -20
echo "=== 末尾 18 行 ==="
tail -18 "$LOG" 2>/dev/null
echo "=== efi 产物 ==="
find /home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/AARCH64 -name "Umi*.efi" 2>/dev/null | head -10
echo "=== FD ==="
ls -la /home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd 2>/dev/null
