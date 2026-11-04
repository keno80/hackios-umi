#!/bin/bash
# 路线 B′：把 boot_progress_stage 的 no-op 桩改接画屏器，需要的前置事实。
set -u
OUT=/mnt/e/Code/HackIos/out/f-stage-route.txt
: > "$OUT"
exec >>"$OUT" 2>&1
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree
X=$T/.cache/xnu-work
U=/home/unixnu/code/UniXNU-umi

echo "== 装配树 patches/xnu 里 z* 的顺序 =="
ls $T/patches/xnu/ | grep '^z' 
echo
echo "== kits 目录实况（main 与装配树）=="
ls -la /home/unixnu/code/UniXNU-main/kits/ 2>&1 | head
echo "---"
ls -la $T/kits/ 2>&1 | head
echo
echo "== boot_progress_stage 全树调用点计数（按文件）=="
grep -rln 'boot_progress_stage' $X 2>/dev/null | while read f; do
  printf '%4d  %s\n' "$(grep -c 'boot_progress_stage' "$f")" "${f#$X/}"
done
echo
echo "== 是否 boot_progress.h 被 C++ 包含 =="
grep -rln 'kern/boot_progress.h' $X 2>/dev/null | sed "s|$X/||"
echo
echo "== 画屏器：init 与 state 处理（video_console.c 里 umi_scr_state / umi_scr_init / umi_screen_text）=="
grep -n 'umi_scr_state\|umi_scr_init\|umi_screen_text\|umi_screen_mark\|v_baseAddr\|ml_io_map' \
  $X/osfmk/console/video_console.c | head -40
echo
echo "== umi_scr_ready/init 函数体 =="
awk '/^umi_scr_init|static .*umi_scr_init|^static int$/{p=1} p&&/umi_scr/{print NR": "$0}' \
  $X/osfmk/console/video_console.c 2>/dev/null | head -5
sed -n '/umi_scr_probe\|umi_scr_init/,/^}/p' $X/osfmk/console/video_console.c | head -60
echo
echo "== umi_screen_text 函数体 =="
sed -n '/^umi_screen_text/,/^}/p' $X/osfmk/console/video_console.c | head -40
echo
echo "== 我们跑 kernel 步的入口脚本 =="
ls /mnt/e/Code/HackIos/tools-wsl/*.sh 2>/dev/null | xargs -n1 basename | head -60
