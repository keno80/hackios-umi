#!/bin/bash
# 出图前的机器闸：走查件里的 mach 段必须真被编成「x16 = 负号」，而不是被 LLVM 悄悄折成大正数
# （(int)x16 才是内核看的值；只要低 32 位是 0xFFFFFFE4 这类，内核读到的就是 -28）。
set -u
O=/mnt/e/Code/HackIos/out/probes/r21-fixture-mach-check.txt
: > "$O"; exec >>"$O" 2>&1
source /usr/local/bin/unixnu-env 2>/dev/null
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
CLT=$TC/CommandLineTools/usr
F=/mnt/e/Code/HackIos/out/fixtures/launchd-walk.macho

echo "== 1. 件身份 =="
ls -la "$F"; sha256sum "$F"

echo
echo "== 2. 反汇编里所有 x16 赋值（看负号形态）=="
"$CLT/bin/otool" -tV "$F" 2>/dev/null | grep -nE "x16" | tail -40

echo
echo "== 3. svc 发数与 mov x16 发数 =="
printf 'svc   = %s\n' "$("$CLT/bin/otool" -tV "$F" 2>/dev/null | grep -c 'svc')"
printf 'x16   = %s\n' "$("$CLT/bin/otool" -tV "$F" 2>/dev/null | grep -c 'x16')"

echo
echo "== 4. mach 段应出现的 9 个号（-28/-29/-27/-26/-89/-16/-19/-18/-31）=="
"$CLT/bin/otool" -tV "$F" 2>/dev/null | grep -E "sub.*x16.*#|mov.*x16.*#|orr.*x16" | tail -14

echo
echo "== 5. 走查件 Q 期判据串仍在（出图闸要查）=="
printf 'Q-PIPE-PAYLOAD=%s\n' "$(strings -a "$F" | grep -c -F 'UMI-WALK-Q-PIPE-PAYLOAD')"
echo "== done $(date -u +%FT%TZ)"
