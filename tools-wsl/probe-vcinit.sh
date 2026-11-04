#!/bin/bash
set -u
R=/home/unixnu/code/umi-work-pin
T=$R/out/umi-xnu/umi/tree/.cache/xnu-work
O=/mnt/e/Code/HackIos/out/probes/vcinit.txt
V=$T/osfmk/console/video_console.c
{
echo "== PE_initialize_console (pe_init.c 190-250)"
sed -n '190,250p' $T/pexpert/arm/pe_init.c
echo
echo "== console_init() (serial_console.c 150-235)"
sed -n '150,235p' $T/osfmk/console/serial_console.c
echo
echo "== video_console.c 里的 IO 映射调用"
grep -n "ml_io_map\|vm_map\|VC_BASE\|vc_map\|map_io\|IO_VIRT" "$V" | head -30
echo
echo "== vc_initialize 前后 (2760-2960)"
sed -n '2760,2960p' "$V" | grep -n "v_baseaddr\|v_rowbytes\|v_width\|v_height\|map\|vc_parse\|boot_arg\|DeviceTree\|return" | head -50
echo
echo "== vc_init / 初始化 vinfo 的函数"
grep -n "^vc_\|^[a-z_]*vc_init\|vc_initialize\|video_console_init\|gc_attach\|gc_ops =" "$V" | head -30
echo
echo "== UMI_EARLY_TRACE 开关如何注入"
grep -rn "UMI_EARLY_TRACE\|early_trace" "$R/devices/umi/bringup/tools/build_umi_xnu.py" | head -30
echo
echo "== 已存在的内核产物"
find "$R/out" -name "*kernel.macho" -printf "%TY-%Tm-%Td %TH:%TM %s %p\n" 2>/dev/null | head -20
echo
echo "== UmiBootLog.c 读取逻辑"
grep -rn "0xb0000000\|0xB0000000\|DARWINBOOT\|needle\|Signature\|pmsg" "$R"/patches/umi-bootlog/UmiBootLog.c 2>/dev/null | head -30
find "$R" -name "UmiBootLog.c" 2>/dev/null | head
} > "$O" 2>&1
wc -l "$O"
