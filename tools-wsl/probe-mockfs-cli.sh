#!/bin/bash
# data_input 的 CLI 接线 + run-05 进度
F=/home/unixnu/code/umi-work-pin/devices/umi/bringup/tools/build_umi_xnu.py
L=/home/unixnu/code/umi-work-pin/out/umi-fw/run-05/firmware.log
{
echo "== data_input 相关行"
grep -n "data_input\|data-input\|volume_uuid\|RamBlock\|ram_block\|NATIVE_RAM" $F | head -30
echo "== add_argument 清单"
grep -n "add_argument" $F | sed 's/  */ /g' | head -40
echo "==== run-05 进度"
echo "存活=$(pgrep -f 'uefi-fw-build run-05' | head -1) clang=$(pgrep -c clang) 日志=$(stat -c %s $L 2>/dev/null)B 改动=$(date -r $L '+%H:%M:%S' 2>/dev/null)"
echo "Building=$(grep -c '^Building' $L 2>/dev/null) error=$(grep -c 'error:' $L 2>/dev/null)"
awk 'length($0)<300' $L 2>/dev/null | grep -E "error:|Error [0-9]|not found" | head -8
awk 'length($0)<200' $L 2>/dev/null | tail -4
} > /mnt/e/Code/HackIos/out/mockfs-cli.txt 2>&1
echo WROTE
