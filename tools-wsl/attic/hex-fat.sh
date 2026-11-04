#!/bin/bash
I=/home/unixnu/code/umi-work-pin/out/umi/xnu/umi-xnu-fat.img
echo "=== 前 64 字节 ==="
xxd -l 64 "$I"
echo "=== 504..512 ==="
xxd -s 504 -l 8 "$I"
echo "=== 第二个扇区（FSInfo?）==="
xxd -s 512 -l 32 "$I"
echo "=== Payloads 目录 ==="
MTOOLS_SKIP_CHECK=1 TZ=UTC mdir -i "$I" -s ::/EFI/UniXNU/Payloads 2>&1 | tail -12
