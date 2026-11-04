#!/bin/bash
# s10 第 5 段空手：先看 dd 抠出来的字节数和 objdump 到底报什么。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s11-diag.txt 2>&1
IMG=/mnt/e/Code/HackIos/out/fixtures/launchd-walk.macho
W=/tmp/fx-s11; rm -rf $W; mkdir -p $W
echo "== otool -l 的 __text 原始段 =="
/opt/unixnu-linux/CommandLineTools/usr/otool -l "$IMG" 2>&1 | grep -A6 'sectname __text'
echo
echo "== 手工抠 14940 起 0x5a4 字节 =="
dd if="$IMG" of=$W/text.bin bs=1 skip=14940 count=1444 status=none
ls -la $W/text.bin
echo
echo "== objdump（把 stderr 也带出来）=="
objdump -D -b binary -m aarch64 --adjust-vma=0x100003a5c $W/text.bin > $W/text.asm 2> $W/text.err
echo "rc=$?"
echo "--- err:"; cat $W/text.err
echo "--- asm 前 12 行:"; head -12 $W/text.asm
echo "--- svc 计数:"; grep -c 'svc' $W/text.asm
echo "--- x16 写入:"; grep -E 'x16' $W/text.asm | head -20
