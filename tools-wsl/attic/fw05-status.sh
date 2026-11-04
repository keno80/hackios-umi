#!/bin/bash
# #8 run-05 进度摘要
L=/home/unixnu/code/umi-work-pin/out/umi-fw/run-05/firmware.log
O=/mnt/e/Code/HackIos/out/probes/fw05-status.txt
{
echo "== 存活: $(pgrep -f 'uefi-fw-build run-05' | head -1) / clang 进程 $(pgrep -c clang)"
echo "== 日志大小: $(stat -c %s "$L" 2>/dev/null) bytes  修改于 $(date -r "$L" '+%H:%M:%S' 2>/dev/null)"
echo "== Building 计数: $(grep -c '^Building' "$L" 2>/dev/null)"
echo "== error 计数: $(grep -c 'error:' "$L" 2>/dev/null)"
echo "== 末尾 8 行"
awk 'length($0)<300' "$L" 2>/dev/null | tail -8
echo "== 首波错误"
awk 'length($0)<300' "$L" 2>/dev/null | grep -E "error:|Error [0-9]|not found|No such file" | head -12
} > $O 2>&1
echo WROTE
