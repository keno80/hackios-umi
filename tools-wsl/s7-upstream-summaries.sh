#!/bin/bash
# 把上游所有机型的 summary 一次性拉出来，用「别人最高到哪儿」给「我们还差多远」定标尺。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s7-upstream-summaries.txt 2>&1
D=/home/unixnu/code/UniXNU-main/docs/.vitepress/device-records

echo "== 1. 机型总数 =="
ls "$D"/*.toml | wc -l

echo
echo "== 2. 每台的第一条 summary（上游水位线）=="
for f in "$D"/*.toml; do
  s=$(grep -m1 '^summary = ' "$f" | cut -c1-260)
  echo "--- $(basename "$f")  $s"
done

echo
echo "== 3. 有没有 umi 的记录 =="
ls "$D" | grep -i 'umi\|vili\|SM8250' || echo "无 umi 记录"

echo
echo "== 4. 顶层 status 取值分布 =="
grep -h '^status = ' "$D"/*.toml | sort | uniq -c | sort -rn | head

echo
echo "== 5. 出现过的最高水位词频（谁真跑起了 SpringBoard / lock screen / launchd）=="
for w in SpringBoard 'lock screen' launchd 'wallpaper' Wi-Fi Metal dyld; do
  n=$(grep -l "$w" "$D"/*.toml 2>/dev/null | wc -l)
  echo "$w -> $n 台"
done
echo "== done $(date -u +%FT%TZ)"
