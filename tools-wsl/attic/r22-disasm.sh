#!/bin/bash
# r21 的 otool 一条没出（stderr 被丢了）。这版把 stderr 收进来，并三选一试出能用的反汇编入口。
set -u
O=/mnt/e/Code/HackIos/out/probes/r22-disasm.txt
: > "$O"; exec >>"$O" 2>&1
source /usr/local/bin/unixnu-env 2>/dev/null
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
CLT=$TC/CommandLineTools/usr
F=/mnt/e/Code/HackIos/out/fixtures/launchd-walk.macho

echo "== 1. otool 存在性 =="
ls -la "$CLT/bin/otool" "$CLT/bin/llvm-objdump" 2>&1 | head

echo
echo "== 2. otool -tV（含 stderr）=="
"$CLT/bin/otool" -tV "$F" 2>&1 | head -12

echo
echo "== 3. llvm-objdump -d --arch=arm64 =="
"$CLT/bin/llvm-objdump" -d --no-show-raw-insn "$F" 2>&1 | tail -60

echo
echo "== 4. objdump 里 x16/svc 计数 =="
printf 'svc=%s x16=%s\n' \
  "$("$CLT/bin/llvm-objdump" -d "$F" 2>/dev/null | grep -c 'svc')" \
  "$("$CLT/bin/llvm-objdump" -d "$F" 2>/dev/null | grep -c 'x16')"
echo "== done $(date -u +%FT%TZ)"
