#!/bin/bash
# 找 boot_progress_stage 的定义与门控：一个钩子接上 mountroot 之后全部进度
set -u
OUT=/mnt/e/Code/HackIos/out/f-bootprogress.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

say "== 定义在哪 =="
grep -rn "^boot_progress_stage\|boot_progress_stage(const\|void.*boot_progress_stage" "$T" --include=*.c --include=*.h 2>/dev/null | head -10 >> "$OUT"
say
say "== 全部调用点分布（按文件计数）=="
grep -rl "boot_progress_stage" "$T" --include=*.c 2>/dev/null | head -20 >> "$OUT"
grep -rc "boot_progress_stage" "$T"/bsd/kern/bsd_init.c "$T"/osfmk/kern/startup.c "$T"/bsd/vfs/vfs_mountroot.c 2>/dev/null >> "$OUT"
say
say "== bsd_init.c 的 bsd_init_kprintf 两个分支的门控（580..595）=="
sed -n '580,596p' "$T/bsd/kern/bsd_init.c" >> "$OUT"
say
say "== boot_progress 的门控变量与 boot-arg 解析 =="
grep -rn "boot_progress_arg\|boot_progress =\|boot_progress_enabled\|\"boot-progress\"" "$T" --include=*.c --include=*.h 2>/dev/null | head -12 >> "$OUT"
say
say "== umi_screen_text 的定义签名（补丁里）=="
grep -n -A6 "^umi_screen_text" /home/unixnu/code/umi-work-pin/devices/umi/patches/umi-xnu/zzzzzzzzzzzzzzzzz-umi-screen.patch | head -24 >> "$OUT"
say "-- 是否非 static / 有没有 prototype --"
grep -n "umi_screen_text\|umi_screen_mark" /home/unixnu/code/umi-work-pin/devices/umi/patches/umi-xnu/zzzzzzzzzzzzzzzzz-umi-screen.patch | head -12 >> "$OUT"
say done
