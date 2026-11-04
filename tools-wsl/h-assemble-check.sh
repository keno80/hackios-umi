#!/bin/bash
# H 步仪器自检：单独汇编 UMI_BAND/UMI_TRACE，确认宏语法与标签展开没问题
set -u
D=/var/tmp/umiband-test
LOG=/mnt/e/Code/HackIos/out/probes/h-assemble.txt
: > "$LOG"
exec >>"$LOG" 2>&1
rm -rf "$D"; mkdir -p "$D"
cp /mnt/e/Code/HackIos/patches/umi-scripts/umi-early-trace.inc "$D/"
{
  echo '#define EXT(x) x'
  echo '#define LEXT(x) L##x:'
  echo '.text'
  cat /mnt/e/Code/HackIos/patches/umi-scripts/umi-early-trace.inc
  echo 'UMI_BAND 1, 0xFF0000FF, x0'
  echo 'UMI_BAND 2, 0xFFFF0000, x20'
  echo 'UMI_BAND 3, 0xFFFFFF00, x20'
  echo 'UMI_TRACE 0x01, x0'
} > "$D/t.S"
cd "$D" || exit 1
echo "== as (GNU as, 仅参考：.endmacro 是 LLVM 方言) =="
aarch64-linux-gnu-as -march=armv8-a -o gnu.o t.S 2>&1 | head -5 || true
echo "== llvm-mc (构建真正用的汇编器) =="
source /usr/local/bin/unixnu-env >/dev/null 2>&1
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
CC="$TC/llvm/bin/clang"
ls -la "$CC" 2>&1 | head -2
if "$CC" --target=arm64-apple-ios17.0 -c t.S -o t.o; then
  echo "AS-OK"
  echo "== disasm =="
  llvm-objdump -d t.o | sed -n '1,46p'
else
  echo "AS-FAIL"
fi
