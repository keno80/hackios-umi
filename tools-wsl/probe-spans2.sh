#!/bin/bash
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/spans2.txt
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
VC=$W/osfmk/console/video_console.c
DB=$W/osfmk/kern/debug.c
AI=$W/osfmk/arm/arm_init.c
SU=$W/osfmk/kern/startup.c
: > "$OUT"
for spec in "VC:$VC:3300:3332" "DB:$DB:1138:1176" "AI:$AI:60:72" "AI2:$AI:556:592" "SU:$SU:72:82" "SU2:$SU:230:240" "SU3:$SU:426:438"; do
  label=${spec%%:*}
  rest=${spec#*:}
  file=${rest%%:*}
  rest2=${rest#*:}
  a=${rest2%%:*}
  b=${rest2#*:}
  echo "===== $label $file $a..$b =====" >> "$OUT"
  awk -v s="$a" -v e="$b" 'NR>=s && NR<=e { printf "%d\t%s\n", NR, $0 }' "$file" >> "$OUT"
done
