#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
K=$WS/out/umi-xnu/umi/kernel/source-kernel.macho
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work
O=/mnt/e/Code/HackIos/out/probes/panic_dis.txt
OD=$(command -v llvm-objdump || echo /usr/bin/llvm-objdump)
{
echo "== objdump: $OD =="
echo "== disasm generatePlatformUUID (0xfffffff007945f14..0xfffffff007946168) =="
"$OD" -d --no-show-raw-insn --start-address=0xfffffff007945f14 --stop-address=0xfffffff007946168 "$K" 2>&1 | tail -n +1
echo "== symbols 0xfffffff0078d0000..0xfffffff0078d6100 =="
awk '$1>="fffffff0078d0000" && $1<="fffffff0078d6100"' /tmp/kalls.txt | head -60
echo "== source: generatePlatformUUID =="
grep -rn "generatePlatformUUID" "$X/bsd/kern" "$X/osfmk" "$X/IOKitKit" 2>/dev/null | head
find "$X" -name 'IOPlatformExpert.cpp' 2>/dev/null | head -3
} > "$O" 2>&1
F=$(find "$X" -name 'IOPlatformExpert.cpp' 2>/dev/null | head -1)
echo "FILE=$F" >> "$O"
if [ -n "$F" ]; then
  echo "== generatePlatformUUID body ==" >> "$O"
  awk '/generatePlatformUUID/{f=1} f{print NR": "$0} f&&/^}/{c++; if(c>2) exit}' "$F" | head -120 >> "$O" 2>&1
fi
echo copied
