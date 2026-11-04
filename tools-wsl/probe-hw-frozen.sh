#!/bin/bash
# 真机停在「exiting boot services」：查画屏器首次触碰是否被提前到 arm_vm_init 内。
set -u
OUT=/mnt/e/Code/HackIos/out/f-hw-frozen.txt
: > "$OUT"
exec >>"$OUT" 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
echo "== arm_init.c 里 boot_progress_stage 两处调用的上下文（540..575）=="
sed -n '535,575p' $X/osfmk/arm/arm_init.c
echo
echo "== kernel_map 在 arm_init.c 里何时被赋值 =="
grep -n 'kernel_map = \|kernel_map=\|kernel_arena' $X/osfmk/arm/arm_init.c | head -20
echo
echo "== video_console.c 自己有没有调 boot_progress_stage（会递归进画屏器）=="
grep -n 'boot_progress_stage' $X/osfmk/console/video_console.c
echo
echo "== umi_screen_text 依赖链：umi_scr_stamp / umi_scr_puts 是否碰 vc 全局 =="
grep -n 'umi_scr_puts\|umi_scr_stamp\|umi_scr_putc' $X/osfmk/console/video_console.c | head -30
echo
echo "== umi_scr_stamp 函数体 =="
sed -n '/^umi_scr_stamp/,/^}/p' $X/osfmk/console/video_console.c | head -40
echo
echo "== ml_io_map_unmappable 在 arm_vm_init 期可用的前置（是否要求 kernel_arena 已建）=="
grep -rn 'ml_io_map_unmappable' $X/osfmk/arm64/ 2>/dev/null | head
echo
echo "== 画屏器 setup 里 ml_io_map_unmappable 之前的全部判据 =="
sed -n '/^umi_scr_setup/,/umi_scr_state = 1/p' $X/osfmk/console/video_console.c | head -40
