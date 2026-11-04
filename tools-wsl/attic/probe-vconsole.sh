#!/bin/bash
set -u
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
O=/mnt/e/Code/HackIos/out/probes/vconsole.txt
{
echo "== 谁调用 console_init_with_context / console_init"
grep -rn "console_init_with_context\|console_init(" "$T/osfmk" 2>/dev/null | head -40
echo
echo "== video_console.c: FB 地址/步长来源"
grep -n "vc_base\|vc_info\|parse_boot_arg\|framebuffer\|ml_io_map\|BOOTCDRAM\|vc_render\|stride\|vinfo" "$T/osfmk/console/video_console.c" | head -80
echo
echo "== arm64 平台层里的 video/display/panic_screen"
grep -rn "console_init\|vc_info\|panic_screen\|display_init\|VideoInfo\|video" "$T/osfmk/arm64" "$T/pexpert/arm" 2>/dev/null | head -60
echo
echo "== pexpert 里的 framebuffer 描述符"
grep -rn "framebuffer\|FrameBuffer\|fb_base\|video" "$T/pexpert" 2>/dev/null | head -40
echo
echo "== umi 补丁里是否已碰 video_console / console"
ls "$T/osfmk/console"
grep -rln "console" /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/patches/umi-xnu/ 2>/dev/null
echo
echo "== optional-legacy-display.patch 全文"
cat /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/patches/umi-xnu/optional-legacy-display.patch
echo
echo "== 我们的 source-kernel.macho 里有没有 video console 符号"
nm /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/build/source-kernel.macho 2>/dev/null | grep -i "vc_\|video_console\|console_init" | head -30
} > "$O" 2>&1
wc -l "$O"
