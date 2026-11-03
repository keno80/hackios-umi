#!/bin/bash
# 阻塞等到 A/B 两条内核构建都起跑，然后打印早期状态（最长 60 分钟）
set -u
L=/home/unixnu/code/UniXNU-main/out/unixnu-logs
deadline=$(( $(date +%s) + 60 * 60 ))
while [ "$(date +%s)" -lt "$deadline" ]; do
  mp=$(cat "$L/kernel-main.pid" 2>/dev/null || true)
  pp=$(cat "$L/kernel-pin.pid" 2>/dev/null || true)
  if [ -n "$mp" ] && [ -n "$pp" ]; then break; fi
  sleep 30
done
[ -n "${mp:-}" ] && [ -n "${pp:-}" ] || { echo "超时：内核构建未起跑"; tail -20 "$L"/wait-*.out; exit 1; }
sleep 90
echo "路B pid=$mp $(kill -0 "$mp" 2>/dev/null && echo 运行中 || echo 已退出)"
echo "路A pid=$pp $(kill -0 "$pp" 2>/dev/null && echo 运行中 || echo 已退出)"
echo "===== 路B 前 40 行 ====="
head -40 "$(cat "$L/kernel-main-latest.txt")"
echo "===== 路A 前 40 行 ====="
head -40 "$(cat "$L/kernel-pin-latest.txt")"
