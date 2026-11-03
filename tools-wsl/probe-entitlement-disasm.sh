#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/entitlement-disasm.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
OBJ=$(command -v llvm-objdump || ls $TC/llvm/bin/llvm-objdump 2>/dev/null | head -1)
say "OBJ=$OBJ"

say "== 1. 定义位置 =="
grep -rn 'IOTaskHasEntitlement' "$X/iokit" 2>/dev/null | head -10 >> "$OUT"

say
say "== 2. 反汇编 _IOTaskHasEntitlement =="
"$OBJ" -d --macho --disassemble-symbols=_IOTaskHasEntitlement "$K" 2>&1 | head -40 >> "$OUT"
say done
