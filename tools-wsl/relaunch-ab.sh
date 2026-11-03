#!/bin/bash
# LF 修复后重新起 A/B 两条内核构建
set -u
L=/home/unixnu/code/UniXNU-main/out/unixnu-logs
mp=$(cat "$L/kernel-main.pid" 2>/dev/null || true)
pp=$(cat "$L/kernel-pin.pid" 2>/dev/null || true)
[ -n "$mp" ] && kill -0 "$mp" 2>/dev/null && { echo "路B 仍在运行 pid=$mp，不重复起"; exit 0; }
[ -n "$pp" ] && kill -0 "$pp" 2>/dev/null && { echo "路A 仍在运行 pid=$pp，不重复起"; exit 0; }
run-kernel-main
run-kernel-pin
echo "== 30 秒后 =="
sleep 30
ab-status | head -40
