#!/bin/bash
# 看 umi_screen_text 周边的精确文本，为「按内容哈希去重」补丁取锚点。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/m18-sig-anchor.txt
: > "$OUT"
exec >>"$OUT" 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
V=$X/osfmk/console/video_console.c

echo "== 1. umi_screen_text 函数体带行号 =="
n=$(grep -n 'umi_screen_text(const char' "$V" | cut -d: -f1)
echo "start line=$n"
sed -n "$((n-6)),$((n+30))p" "$V" | nl -ba -v$((n-6))

echo
echo "== 2. sig_a 全部出现点 =="
grep -n 'umi_scr_sig_a' "$V"

echo
echo "== 3. sig_kind 全部出现点（看 kind 语义）=="
grep -n 'umi_scr_sig_kind' "$V"

echo
echo "== 4. 锚点唯一性 =="
for a in 'umi_scr_sig_a == (unsigned long) umi_message' 'umi_scr_sig_a = (unsigned long) umi_message'; do
  printf '%s -> %s\n' "$a" "$(grep -cF "$a" "$V")"
done

echo
echo "== 5. 函数定义可插位置：umi_screen_text 之前的完整上下文 =="
sed -n "$((n-20)),$((n+2))p" "$V"

echo
echo "== 6. 构建是否已停 =="
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
P=$(cat "$LOGD/kernel-walk.pid" 2>/dev/null)
[ -n "$P" ] && kill -0 "$P" 2>/dev/null && echo "STILL-ALIVE pid=$P" || echo "DEAD-OK"
echo "== done $(date -u +%FT%TZ)"
