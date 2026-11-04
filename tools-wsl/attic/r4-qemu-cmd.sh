#!/bin/bash
# R 步之四：run_umi_qemu.py 把 --owned-memory-mib 限死在 (256,320,512)，dram-size 硬编码 1 GiB，
# 而真机是 8G 机器、DXE 期最大连续 5 GiB。要判「这条 zalloc panic 是不是内存规模驱动」，
# 得绕开这个 choices 直接调底层命令——先把 200~250 行的拼装原文取出来照抄。
set -u
LOG=/mnt/e/Code/HackIos/out/probes/r4-qemu-cmd.txt
: > "$LOG"
exec >> "$LOG" 2>&1
W=/home/unixnu/code/umi-work-pin

echo "== run_umi_qemu.py 195~250 行 =="
awk 'NR>=195 && NR<=250 {printf "%4d  %s\n", NR, $0}' "$W/tools/run_umi_qemu.py"
echo
echo "== owned-memory-size / dram-size 这两个参数被谁吃（底层脚本）=="
grep -rn "owned-memory-size\|owned_memory_size\|dram-size\|dram_size" "$W/tools" 2>/dev/null | head -20
echo
echo "== 底层脚本里这两个值怎么变成内存图 =="
for f in $(grep -rl "owned-memory-size\|owned_memory_size" "$W/tools" 2>/dev/null | head -3); do
  echo "-- $f"
  grep -nE "owned_memory_size|dram_size|memory-map|PhysicalMemory|ram" "$f" | head -25
done
echo "== done $(date -u +%FT%TZ)"
