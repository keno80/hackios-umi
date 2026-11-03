#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/ramdisk-handoff.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
S=/home/unixnu/code/UniXNU-main
W=/home/unixnu/code/umi-work-pin
SC=$S/scripts

say "== 1. RAMDisk / PackedRAMDisk 在脚本层的写入处 =="
grep -rn 'RAMDisk' "$SC"/unixnu/devicetree.py "$SC"/umi_adt.py "$SC"/qemu-entry/make-dt.py 2>/dev/null | head -25 >> "$OUT"

say
say "== 2. probe-darwinboot-xnu.py 怎么把 RAM 盘交给内核 =="
grep -n 'RAMDisk\|ramdisk\|memory-map\|memory_map\|rd=\|root.img\|native_user_image\|window' "$SC/probe-darwinboot-xnu.py" | head -40 >> "$OUT"

say
say "== 3. window parser：loader-owned 区间怎么分配 =="
sed -n '1,60p' "$SC/check-darwinboot-window-parser.py" >> "$OUT" 2>&1

say
say "== 4. run_umi_qemu.py：有没有 native-user/rd 的入口 + 默认 args =="
grep -n 'native\|add_argument\|args = \|a\.args' "$W/tools/run_umi_qemu.py" | head -40 >> "$OUT"

say
say "== 5. build-mockfs-fixture.py 产出物清单（是否含 root.img）=="
grep -n 'write\|out /\|root\.img\|image' "$S/scripts/build-mockfs-fixture.py" 2>/dev/null | head -25 >> "$OUT"
ls -la "$W/out/umi-xnu/umi/tree/build/mockfs-fixture" 2>/dev/null | head -12 >> "$OUT"

say
say "== 6. 板子 kernel_args 现值 =="
grep -n 'kernel_args\|packed_data_ramdisk\|initrd\|ramdisk' "$S/../UniXNU-umi/board.toml" 2>/dev/null | head -10 >> "$OUT"
find /home/unixnu/code -maxdepth 2 -name board.toml 2>/dev/null | head -5 >> "$OUT"
say done
