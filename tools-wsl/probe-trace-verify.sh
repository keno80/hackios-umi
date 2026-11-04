#!/bin/bash
# 静态核对 trace 档内核：打点前缀字符串、start.o 里的 0xB0000000 块映射
set -u
OUT=/mnt/e/Code/HackIos/out/g-trace-verify.txt
: > "$OUT"
exec >>"$OUT" 2>&1
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/entry-trace-kernel.macho
S=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho
echo "== 尺寸/指纹 =="
ls -la "$K" "$S"
sha256sum "$K" "$S"
echo
echo "== 打点前缀字符串命中数 trace / baseline =="
echo "trace=$(strings -a "$K" | grep -c 'UMI XNU')"
echo "base=$(strings -a "$S" | grep -c 'UMI XNU')"
echo
echo "== start.o 反汇编里对 0xB0000000 的引用 =="
O=$(find /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/xnu/ios-obj -name 'start.o' 2>/dev/null | head -1)
echo "obj=$O"
OD=/opt/unixnu-linux/llvm/bin/llvm-objdump
if [ -n "$O" ]; then
  "$OD" -d --triple=aarch64 "$O" 2>/dev/null | grep -iE 'b0000000|0x#?b000' | head -10
  echo "hits=$("$OD" -d --triple=aarch64 "$O" 2>/dev/null | grep -icE 'b0000000')"
fi
echo "DONE"
