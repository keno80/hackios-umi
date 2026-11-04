#!/bin/bash
# M 步判读：走查区读回全是 "E14"（读失败），且停在 _Assert。
# 先搞清 E14 是哪条代码路径产生的、_Assert 是谁触发的，再把 screen.png 取回 Windows。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/m12-why-e14.txt
: > "$OUT"
exec >>"$OUT" 2>&1

WS=/home/unixnu/code/umi-work-pin
R=$WS/out/umi-qemu/run-21-walk
G=$WS/sources/UniXNU/scripts/qemu-entry/gdb-stop.py

echo "== 0. gdb-stop.py 在哪 =="
ls -la "$G" || for f in $(find /home/unixnu/code/umi-work-pin -name 'gdb-stop.py' 2>/dev/null | head -5); do echo "$f"; done
G=$(find /home/unixnu/code/umi-work-pin -name 'gdb-stop.py' 2>/dev/null | head -1)

echo
echo "== 1. memory / read-memory 相关代码 =="
grep -n 'read-memory\|read_memory\|"memory"\|memory\[' "$G" | head -40

echo
echo "== 2. 短错误标记从哪来（E14 之类）=="
grep -n 'E%d\|"E"\|except\|str(e)\|format_exc\|short' "$G" | head -60

echo
echo "== 3. 单个 --read-memory 的处理函数全文 =="
python3 - "$G" <<'PY'
import re, sys, pathlib
src = pathlib.Path(sys.argv[1]).read_text()
# 打印包含 ex memória / memory 读定义的函数体
for m in re.finditer(r'(?m)^(def [^\n]*\b(memory|mem|read)[^\n]*:.*)', src, re.I):
    start = m.start()
    print('----', src[m.start():m.start()+80].split('\n')[0])
    print('\n'.join(src[start:].split('\n')[:60]))
    print()
PY

echo
echo "== 4. runner.log 全文 =="
cat "$R/runner.log" 2>/dev/null || echo NO-RUNNER-LOG

echo
echo "== 5. gdb-stderr.log 全文 =="
cat "$R/gdb-stderr.log" 2>/dev/null || echo NO-STDERR

echo
echo "== 6. gdb-uart.log 全文 =="
cat "$R/gdb-uart.log" 2>/dev/null || echo NO-UART

echo
echo "== 7. stop_symbol=_Assert 的现场：符号反查 =="
grep -n 'stop_symbol\|_Assert\|Assert' "$G" | head -30

echo
echo "== 8. 取回 screen.png =="
cp "$R/screen.png" /mnt/e/Code/HackIos/out/screens/qemu-run-21-walk.png 2>/dev/null && \
  sha256sum /mnt/e/Code/HackIos/out/screens/qemu-run-21-walk.png || echo NO-SCREEN

echo
echo "== 9. 内核里 _Assert 附近（用 nm/strings 双试）=="
K=$WS/out/umi-xnu/umi/kernel/source-kernel.macho
file "$K" | head -1
python3 -c "
import sys
addr=0xfffffff007a0c678
print('stop addr = 0x%x' % addr)
"
echo "-- 内核链接基址/段信息 --"
/opt/unixnu-linux/CommandLineTools/usr/bin/otool -l "$K" 2>/dev/null | head -40 || echo "NO-OTOOL"
echo "== done $(date -u +%FT%TZ)"
