#!/bin/bash
# 跳过与上游 main 重复的 umi 补丁，重跑路B（官方 Linux 支持那条）
set -u
R=/home/unixnu/code/UniXNU-umi
P=$R/patches/umi-xnu/optional-legacy-display.patch
if [ -f "$P" ]; then
  mv "$P" "$P.upstream-duplicate"
  echo "已停用：$(basename "$P").upstream-duplicate"
else
  echo "补丁不在了（可能已停用）：$(ls "$R/patches/umi-xnu/" | head -30 | tr '\n' ' ')"
fi
echo "当前 umi 补丁列表：$(ls "$R/patches/umi-xnu/"/*.patch 2>/dev/null | xargs -n1 basename | tr '\n' ' ')"
run-kernel-main
