#!/bin/bash
# R 步之十四：Darwin 侧 otool 的 llvm 反汇编器在这个定制工具链里缺失（"can't create arm64 llvm disassembler"），
# 静态验 mach 段编码只能走 Linux binutils：把 __text 抠出来，用 objdump -b binary -m aarch64 反汇编，
# 确认 9 发 x16 真是负数（内核读的是 (int)x16，低 32 位对就行）。
set -u
O=/mnt/e/Code/HackIos/out/probes/r23-objdump-mach.txt
: > "$O"; exec >>"$O" 2>&1
source /usr/local/bin/unixnu-env 2>/dev/null
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
CLT=$TC/CommandLineTools/usr
F=/mnt/e/Code/HackIos/out/fixtures/launchd-walk.macho
W=/tmp/fx-dis

echo "== 1. objdump 支持的 target =="
objdump --info 2>/dev/null | grep -iE "aarch64|arm" | head -6

echo
echo "== 2. __text 的 fileoff/size =="
"$CLT/bin/otool" -l "$F" 2>/dev/null | grep -A5 'sectname __text' | sed -n '1,8p'
OFF=$("$CLT/bin/otool" -l "$F" 2>/dev/null | grep -A5 'sectname __text' | awk '/fileoff/{print $2; exit}')
SZ=$("$CLT/bin/otool" -l "$F" 2>/dev/null | grep -A5 'sectname __text' | awk '/filesize/{print $2; exit}')
echo "OFF=$OFF SZ=$SZ"

echo
echo "== 3. 抠出来反汇编 =="
rm -rf "$W"; mkdir -p "$W"
dd if="$F" of="$W/text.bin" bs=1 skip="$OFF" count="$SZ" status=none
objdump -D -b binary -m aarch64 -M no-aliases "$W/text.bin" > "$W/text.asm" 2>&1
head -6 "$W/text.asm"
printf 'svc=%s  x16=%s\n' "$(grep -c 'svc' "$W/text.asm")" "$(grep -c 'x16' "$W/text.asm")"

echo
echo "== 4. 所有写 x16 的指令（mach 段应见 -28/-29/-27/-26/-89/-16/-19/-18/-31）=="
grep -nE "x16" "$W/text.asm" | tail -40

echo
echo "== 5. 尾段（最后 60 行，mach 段就在末尾）=="
tail -60 "$W/text.asm"
echo "== done $(date -u +%FT%TZ)"
