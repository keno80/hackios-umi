#!/bin/bash
# R 步之五：先查上游有没有踩过同一条 zalloc panic——device-records 是逐机型的硬教训集，
# 作者若已在 umi/alioth 上记过 zone/kt_fixed_zones 的机型差异，能省掉一整轮瞎猜。
set -u
LOG=/mnt/e/Code/HackIos/out/probes/r5-upstream-zidx.txt
: > "$LOG"
exec >> "$LOG" 2>&1

for D in /home/unixnu/code/UniXNU-main /home/unixnu/code/umi-work-pin; do
  echo "===== $D ====="
  [ -d "$D" ] || { echo "不存在"; continue; }
  echo "-- 关键词命中（zidx / zalloc / kt_fixed_zones / VM map entries / index confusion）--"
  grep -rniE "invalid zidx|index confusion|kt_fixed_zones|VM map entries|zalloc" \
    "$D/docs" "$D/devices" "$D/bringup" "$D/*.md" 2>/dev/null | grep -v '^Binary' | head -30
  echo "-- device-records 里 umi/alioth 的硬教训条数 --"
  ls "$D"/docs/.vitepress/device-records/ 2>/dev/null | head -20
  echo
done

echo "== umi.toml 设备记录全文（若存在）=="
find /home/unixnu/code -maxdepth 6 -name 'umi.toml' -path '*device-records*' 2>/dev/null | head -3
U=$(find /home/unixnu/code -maxdepth 6 -name 'umi.toml' -path '*device-records*' 2>/dev/null | head -1)
[ -n "$U" ] && cat "$U"
echo "== done $(date -u +%FT%TZ)"
