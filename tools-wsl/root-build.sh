#!/bin/bash
# 找作者产出 qemu-owner-root-* 内核的构建入口与配置
{
  cd /home/unixnu/code/umi-work-pin || exit 1
  echo "== grep owner_root / owner-root（排除 out）"
  grep -rn "owner_root\|owner-root" --include="*.py" --include="*.toml" --include="*.sh" --include="*.json" --include="*.md" . 2>/dev/null | grep -v "^./out/" | grep -v "^./sources/" | head -40
  echo "== tools 里 storage provider / root trace 相关脚本"
  ls tools | grep -i "storage\|root\|owner\|provider"
  echo "== devices/umi/scripts"
  ls devices/umi/scripts | head -40
  echo "== devices/umi/configs"
  ls devices/umi/configs | head -40
  echo "== board.toml 里 profile/kernel 段"
  grep -n -A12 "\[kernel\]\|\[profiles\|\[build\]" devices/umi/board.toml | head -60
} > /mnt/e/Code/HackIos/out/root-build.txt 2>&1
echo WROTE
