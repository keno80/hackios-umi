#!/bin/bash
set -u
R=/home/unixnu/code/umi-work-pin
T=$R/out/umi-xnu/umi/tree/.cache/xnu-work
P=$R/out/umi-xnu/umi/tree/patches/umi-xnu
O=/mnt/e/Code/HackIos/out/probes/screenfont.txt
{
echo "== iso_font.c 头部与符号"
head -30 "$T/osfmk/console/iso_font.c"
grep -n "iso_font\|ISO_CHAR" "$T/osfmk/console/video_console.h" | head -20
echo
echo "== console/Makefile 是否编 arm64"
cat "$T/osfmk/console/Makefile" | head -60
echo
echo "== 内核里是否已有 iso_font 符号"
K=$R/out/umi-xnu/umi/kernel/source-kernel.macho
ls -l "$K"
nm "$K" 2>/dev/null | grep -i "iso_font\|vc_initialize\|gc_ops\|video_console\|PE_create_console\|ml_io_map_unmappable" | head -20
echo
echo "== umi-early-trace.inc 是怎么进树的（谁创建这个文件）"
grep -rln "umi-early-trace.inc" "$P" | head
grep -rn "umi-early-trace\|/dev/null" "$P"/*.patch | grep -c "dev/null"
grep -rn "^new file\|/dev/null" "$P"/early-entry-trace.patch | head
echo
echo "== patches 的应用方式"
grep -rn "patches/umi-xnu\|apply\|git apply\|patch -" "$R/scripts" "$R/devices/umi" 2>/dev/null | grep -v Binary | grep -i "patch" | head -20
echo
echo "== ml_io_map_unmappable 原型"
sed -n '720,760p' "$T/osfmk/arm/machine_routines.h"
echo
echo "== PE_state 结构与 v_* 字段"
sed -n '280,300p' "$T/pexpert/pexpert/pexpert.h"
} > "$O" 2>&1
wc -l "$O"
