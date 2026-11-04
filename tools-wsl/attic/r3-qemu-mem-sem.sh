#!/bin/bash
# R 步之三：QEMU 侧的内存是从 --owned-memory-mib 来的，真机是 8G 机器上实测的 5 GiB 连续窗。
# 先搞清这个选项在 run_umi_qemu.py 里到底动了什么，再决定用哪档 RAM 复现真机的 zalloc panic。
set -u
LOG=/mnt/e/Code/HackIos/out/probes/r3-qemu-mem-sem.txt
: > "$LOG"
exec >> "$LOG" 2>&1
W=/home/unixnu/code/umi-work-pin

echo "== --owned-memory-mib 的定义与消费点 =="
grep -nE "owned_memory_mib|owned-memory-mib|owned_mem" "$W/tools/run_umi_qemu.py" | head -30
echo
echo "== QEMU 命令行拼装（-m / memmap / dtb）=="
grep -nE '"-m"|'"'"'-m'"'"'|mem|dtb|append|cmd' "$W/tools/run_umi_qemu.py" | head -40
echo
echo "== 默认档位 =="
grep -nE "default=.*256|choices" "$W/tools/run_umi_qemu.py" | head -10
echo "== done $(date -u +%FT%TZ)"
