#!/bin/bash
# 谁在吃 WSL 的内存：残留 qemu / 双份构建 / page 缓存。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/n11-host-mem.txt
: > "$OUT"
exec >>"$OUT" 2>&1

echo "== 1. 内存 =="
free -m
echo
echo "== 2. qemu 进程 =="
ps -eo pid,etimes,rss,cmd | grep -i '[q]emu-system' | head -10
echo "qemu 计数=$(ps -e -o cmd | grep -c '[q]emu-system')"
echo
echo "== 3. 构建进程 =="
ps -eo pid,etimes,rss,cmd | grep -E '[b]uild_umi_xnu|[n]inja|[m]ake' | head -10
echo
echo "== 4. 最占内存的 12 个进程 =="
ps -eo pid,rss,cmd --sort=-rss | head -13
echo
echo "== 5. WSL 侧 overcommit / cgroup 限制 =="
cat /proc/meminfo | grep -E 'MemAvailable|SwapTotal|CommitLimit|Committed_AS'
cat /sys/fs/cgroup/memory.max 2>/dev/null || echo "no cgroup v2 memory.max"
echo "== done $(date -u +%FT%TZ)"
