#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
K=$WS/out/umi-xnu/umi/kernel/source-kernel.macho
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work
O=/mnt/e/Code/HackIos/out/probes/sha1_dis.txt
{
echo "== disasm sha1_init 0xfffffff0078dbb08..0xfffffff0078dbc10 =="
llvm-objdump -d --start-address=0xfffffff0078dbb08 --stop-address=0xfffffff0078dbc10 "$K" 2>&1 | tail -n +5
echo "== sleh.c panic_plain around 489 =="
awk 'NR>=455 && NR<=530 {printf "%4d  %s\n", NR, $0}' "$X/osfmk/arm64/sleh.c"
echo "== sha1 source =="
ls "$X/bsd/libkern/" 2>/dev/null | grep -i sha1
awk 'NR>=1 && NR<=80 {printf "%4d  %s\n", NR, $0}' "$X/bsd/libkern/sha1.c" 2>/dev/null
echo "== SHA1Init body =="
grep -n -A20 "^SHA1Init" "$X/bsd/libkern/sha1.c" 2>/dev/null | head -40
} > "$O" 2>&1
echo copied
