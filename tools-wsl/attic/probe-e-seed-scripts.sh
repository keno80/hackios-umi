#!/bin/bash
# E 步补测：三个 data-seed 脚本的 Mac 依赖到底卡在哪一步，有没有非 macOS 分支
set -u
OUT=/mnt/e/Code/HackIos/out/probes/e-seed-scripts.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
S=/home/unixnu/code/UniXNU-main

for f in make-data-seed.py seed-data-grow.py seed-data-skip-setup.py; do
  say "===== $f（$(wc -l < "$S/scripts/$f") 行）====="
  say "-- docstring 前 12 行 --"
  sed -n '1,12p' "$S/scripts/$f" >> "$OUT"
  say "-- platform / macOS 判定 --"
  grep -n "platform\|darwin\|macos\|hdiutil\|diskutil\|tool(" "$S/scripts/$f" | head -20 >> "$OUT"
  say
done

say "== udif.py 是不是完整的非 macOS 分支（能读 DMG 就不需要 hdiutil attach）=="
sed -n '1,15p' "$S/scripts/unixnu/udif.py" >> "$OUT"
grep -n "def \|BKGD\|zlib\|lzvn\|lzfse\|blas" "$S/scripts/unixnu/udif.py" | head -20 >> "$OUT"

say
say "== userdata.py 的 os_mount 在非 macOS 上走哪条 =="
sed -n '45,95p' "$S/scripts/unixnu/userdata.py" >> "$OUT"

say
say "== payload.py:90 的 hdiutil 是为哪一步 =="
sed -n '80,96p' "$S/scripts/unixnu/payload.py" >> "$OUT"

say
say "== 本机 umi 工具里唯一的 hdiutil/diskutil 引用 =="
grep -n "hdiutil\|diskutil" /home/unixnu/code/umi-work-pin/tools/prepare_umi_root.py | head >> "$OUT"
say "-- 上下文 --"
grep -n -B4 -A4 "hdiutil" /home/unixnu/code/umi-work-pin/tools/prepare_umi_root.py | head -30 >> "$OUT"
say done
