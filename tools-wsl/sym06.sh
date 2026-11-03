#!/bin/bash
# 归因 run-06-root 的超时停点：符号化 pc/lr/ELR + uart 尾部 + 停点 json
export PATH=/opt/unixnu-linux/CommandLineTools/usr/bin:/opt/unixnu-linux/bin:/usr/local/bin:/usr/bin:/bin
export LC_ALL=C
D=/home/unixnu/code/umi-work-pin/out/umi-qemu/run-06-root
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho
{
  echo "== dir"; ls -l "$D"
  echo "== uart 行数=$(wc -l < "$D/gdb-uart.log" 2>/dev/null || echo 0)"
  awk 'length($0)<300' "$D/gdb-uart.log" 2>/dev/null | tail -14
  echo "== sym"
  python3 /mnt/e/Code/HackIos/tools-wsl/sym_stop.py "$D" "$K"
  echo "== stop json 关键字段"
  python3 -c "
import json
s=json.load(open('$D/gdb-stop.json'))
print({k:s[k] for k in list(s)[:12] if not k.startswith('x')})
print('frame_chain 长度=', len(s.get('frame_chain',[])))
"
} > /mnt/e/Code/HackIos/out/run06-sym.txt 2>&1
echo WROTE
