#!/bin/bash
set -u
D=/home/unixnu/code/umi-work-pin/sources/UniXNU/drivers
LOG=/mnt/e/Code/HackIos/out/probes/fb-console.txt
{
  echo "== 命中 PE_Video/IOFB/video_console 的文件"
  grep -rl -E 'PE_Video|IOFB|video_console|v_baseAddr' "$D" 2>/dev/null | head -12
  echo "== 细节"
  grep -rn -E 'PE_Video|IOFB|video_console|v_baseAddr|stdout-path' "$D" 2>/dev/null | head -25
  echo "== DarwinBoot 里的 display 相关"
  grep -n -E 'Video|IOFB|Display|GOP|framebuffer' "$D/DarwinBoot/DarwinBootPkg/Driver/DarwinBoot.c" | head -30
  echo "== 我们内核源码里 video_console 是否启用（XNU 树）"
  X=/home/unixnu/code/umi-work-pin/sources/xnu
  ls -d "$X" 2>/dev/null || X=$(ls -d /home/unixnu/code/umi-work-pin/sources/*/ | head -8 | tr '\n' ' ')
  echo "  候选源: $X"
} > "$LOG" 2>&1
