#!/bin/bash
# Extract the painter tail + the real kernel font, then compile the host harness.
set -uo pipefail

XNU=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
VC=$XNU/osfmk/console/video_console.c
FONT=$XNU/osfmk/console/iso_font.c
SRC=/mnt/e/Code/HackIos/tools-wsl/umi-screen-test
DIR=/home/unixnu/umi-screen-test

mkdir -p "$DIR"
cp "$SRC/umi_screen_harness.c" "$DIR/test_umi_screen.c"
head -2 "$DIR/test_umi_screen.c"

end=$(grep -n '^};' "$FONT" | head -1 | cut -d: -f1)
{ sed -n "47,${end}p" "$FONT"; grep '#define ISO_CHAR' "$FONT"; } > "$DIR/umi_test_font.h"

start=$(grep -n '#define UMI_SCR_SCALE' "$VC" | cut -d: -f1)
echo "tail starts at video_console.c:$start"
sed -n "${start},\$p" "$VC" > "$DIR/umi_test_part.c"

cd "$DIR"
gcc -O1 -std=gnu11 -Wall -Wextra -Wno-unused-parameter -o test_umi_screen test_umi_screen.c
rc=$?
echo "compile rc=$rc"
[ $rc -ne 0 ] && exit $rc

./test_umi_screen normal.ppm
./test_umi_screen openloop out-openloop.ppm
./test_umi_screen panic out-panic.ppm
ls -l "$DIR"/*.ppm
