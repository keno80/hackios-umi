#!/bin/bash
OUT=/mnt/e/Code/HackIos/out/ram-cli.txt
: > "$OUT"
WS=/home/unixnu/code/umi-work-pin
echo "== 1. prepare CLI 参数" >> "$OUT"
sed -n '425,445p' "$WS/tools/prepare_umi_uefi.py" >> "$OUT" 2>&1
echo "== 2. uefi-binaries 目录在哪（prepare --binaries 的入参）" >> "$OUT"
find "$WS" -maxdepth 4 -type d -name "uefi-binaries" 2>/dev/null | head -5 >> "$OUT"
ls -la "$WS"/out/*uefi-binaries* 2>/dev/null | head -10 >> "$OUT"
python3 -c "
import json,glob
for p in glob.glob('$WS/**/uefi-binaries/manifest.json', recursive=True)[:3]:
    m=json.load(open(p)); print(p, '->', {k:m[k] for k in list(m)[:6]})" >> "$OUT" 2>&1
echo "== 3. Binaries/umi 现在指向" >> "$OUT"
ls -la /home/unixnu/code/uefi-umi-b/Binaries/ 2>/dev/null >> "$OUT"
echo "== 4. make_umi_payload CLI" >> "$OUT"
tail -25 "$WS/tools/make_umi_payload.py" >> "$OUT" 2>&1
echo "== 5. 当前 uefi 树被 prepare 改过哪些文件" >> "$OUT"
git -C "$WS/sources/uefi-umi" status --porcelain 2>&1 | head -20 >> "$OUT"
echo "== 6. unixnu-memory.toml 内容（会显示什么）" >> "$OUT"
cat "$WS/devices/umi/package/unixnu-memory.toml" 2>/dev/null | head -40 >> "$OUT"
echo WROTE >> "$OUT"
