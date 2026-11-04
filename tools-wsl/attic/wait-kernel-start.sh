#!/bin/bash
# 阻塞到工具链结束并确认 A/B 两条内核构建都起跑（最长 50 分钟）
set -u
L=/home/unixnu/code/UniXNU-main/out/unixnu-logs
deadline=$(( $(date +%s) + 50 * 60 ))
while [ "$(date +%s)" -lt "$deadline" ]; do
  mp=$(cat "$L/kernel-main.pid" 2>/dev/null || true)
  pp=$(cat "$L/kernel-pin.pid" 2>/dev/null || true)
  if [ -n "$mp" ] && [ -n "$pp" ]; then
    sleep 25
    echo "路B pid=$mp $(kill -0 "$mp" 2>/dev/null && echo 运行中 || echo 已退出)"
    echo "路A pid=$pp $(kill -0 "$pp" 2>/dev/null && echo 运行中 || echo 已退出)"
    echo "===== 等待器输出 ====="
    cat "$L"/wait-*.out
    echo "===== 路B 头 30 行 ====="
    head -30 "$(cat "$L/kernel-main-latest.txt")"
    echo "===== 路A 头 30 行 ====="
    head -30 "$(cat "$L/kernel-pin-latest.txt")"
    exit 0
  fi
  sleep 20
done
echo "超时：内核构建未起跑"
echo "===== 工具链尾部 ====="
tail -30 "$(cat "$L/latest.txt" 2>/dev/null)"
echo "===== 等待器尾部 ====="
tail -30 "$L"/wait-*.out
exit 1
