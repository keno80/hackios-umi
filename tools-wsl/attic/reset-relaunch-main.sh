#!/bin/bash
# 把路B(main) 的 xnu 工作树清干净再重跑（main 的脚本不会自己复位，重复跑会残留补丁状态）
set -u
W=/home/unixnu/code/UniXNU-main/out/umi/tree
mp=$(cat /home/unixnu/code/UniXNU-main/out/unixnu-logs/kernel-main.pid 2>/dev/null || true)
if [ -n "$mp" ] && kill -0 "$mp" 2>/dev/null; then echo "路B 仍在运行 pid=$mp"; exit 0; fi
if [ -d "$W/.cache/xnu-work" ]; then
  n=$(git -C "$W/.cache/xnu-work" status --porcelain | wc -l)
  echo "旧工作树改动文件数=$n，删除后由 refer/xnu 重新 clone"
  rm -rf "$W/.cache/xnu-work"
fi
run-kernel-main
