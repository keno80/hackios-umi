#!/bin/bash
# 判定：Linux 上能否用 IPSW 造出 userdata-root.img（不依赖 macOS hdiutil）
set -u
OUT=/mnt/e/Code/HackIos/out/ipsw-path.txt
U=/home/unixnu/code/UniXNU-main
W=/home/unixnu/code/umi-work-pin
{
  echo "== userdata.py 的 attach/image_size 实现"
  f=$(ls $U/scripts/unixnu/userdata.py 2>/dev/null || find /home/unixnu/code -name userdata.py -path '*unixnu*' 2>/dev/null | head -1)
  echo "文件: $f"
  grep -n 'hdiutil\|attach\|dmg\|7z\|ipsw\|def image_size\|def attach\|subprocess' "$f" | head -25
  echo
  echo "== prepare_umi_root 主体（85-140 行）"
  sed -n '85,140p' $W/tools/prepare_umi_root.py
  echo
  echo "== 本地是否已有 ipsw / dmg / 大镜像"
  timeout 120 find /home/unixnu /mnt/e/Code/HackIos -maxdepth 4 \( -name '*.ipsw' -o -name '*.dmg' \) 2>/dev/null | head -10
  echo "-- 大于 200M 的文件 --"
  timeout 120 find /home/unixnu/code -maxdepth 5 -type f -size +200M 2>/dev/null | head -10
  echo
  echo "== devices/umi 里声明的 userdata 几何与 IPSW 校验"
  grep -n 'userdata\|ipsw\|sha256\|restore' $W/devices/umi/board.toml 2>/dev/null | head -20
  echo
  echo "== 上游文档：Linux 上能否造根卷"
  grep -rn --include=*.md -i 'hdiutil\|ipsw' $U/docs/zh 2>/dev/null | head -12
} > "$OUT" 2>&1
echo WROTE
