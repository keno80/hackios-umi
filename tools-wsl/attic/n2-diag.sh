#!/bin/bash
# 诊断：n2 报「line 58 syntax error near unexpected token '('」，但那段是双引号里的正则，
# 只可能是前面某处引号失衡把后面整段吞了。这里查行尾符 + bash -n + 原文，定位到真正失衡的那行。
set -u
O=/mnt/e/Code/HackIos/out/probes/n2-diag.txt
: > "$O"
exec >>"$O" 2>&1
P=/mnt/e/Code/HackIos/tools-wsl/n2-qemu-regress-28z.sh

echo "== 1. 行尾符 =="
file "$P"
printf 'CR count = %s\n' "$(tr -cd '\r' < "$P" | wc -c)"
printf 'lines    = %s\n' "$(wc -l < "$P")"

echo
echo "== 2. bash -n 语法检查 =="
bash -n "$P"

echo
echo "== 3. 带行号原样输出（cat -A 看不可见字符）=="
cat -n "$P" | sed -e 's/\$$/<EOL>/'
echo "== done $(date -u +%FT%TZ)"
