#!/bin/bash
# 面板有没有「画满 N 行就停」的硬闸；顺带看构建进度。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/m17-panel-cap-and-build.txt
: > "$OUT"
exec >>"$OUT" 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
WS=/home/unixnu/code/umi-work-pin

echo "== 1. umi_screen_text 全文 =="
awk '/umi_screen_text/,0' "$X/osfmk/console/video_console.c" | head -70

echo
echo "== 2. 任何上限/停止条件 =="
grep -n 'umi_scr_total\|umi_scr_reps\|halted\|UMI_SCR_MAX\|>= *[0-9]\{2,\}\|return' \
  "$X/osfmk/console/video_console.c" | sed -n '1,60p'

echo
echo "== 3. 可见行数：rows 怎么算 =="
grep -n 'umi_scr_rows\|umi_scr_cols\|ISO_CHAR_HEIGHT\|ISO_CHAR_WIDTH\|umi_scr_y0\|umi_scr_scale' \
  "$X/osfmk/console/video_console.c" | head -40

echo
echo "== 4. 构建进度 =="
P=$(cat "$LOGD/kernel-walk.pid" 2>/dev/null)
if [ -n "$P" ] && kill -0 "$P" 2>/dev/null; then echo "ALIVE pid=$P"; else echo "DEAD"; fi
L=$(cat "$LOGD/kernel-walk-latest.txt")
sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' "$L" 2>/dev/null | tail -8
KL=$(ls -t $WS/out/umi-xnu/umi/logs/*/kernel.log 2>/dev/null | head -1)
echo "-- kernel.log: $KL"
sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' "$KL" 2>/dev/null | tail -12
echo "== done $(date -u +%FT%TZ)"
