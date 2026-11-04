#!/bin/bash
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
LOG=$(ls -t "$LOGD"/kernel-screen-*.log | head -1)
echo "=== head -40 $LOG ==="
head -40 "$LOG"
echo "=== new kernel artifacts ==="
find /home/unixnu/code/umi-work-pin/out -maxdepth 5 -name '*.macho' -printf '%TY-%Tm-%Td %TH:%TM:%TS %10s %p\n' 2>/dev/null | sort
echo "=== xnu-work video_console tail check ==="
grep -c 'UMI_SCR_SCALE_MAX' /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work/osfmk/console/video_console.c
