#!/bin/bash
# 交付前双证：镜像里真的是走查件 + 新内核吗（strings 在整块镜像上会假阴性，用 toml+偏移双证）。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/m20-walk-img-check.txt
: > "$OUT"
exec >>"$OUT" 2>&1
IMG=/mnt/e/Code/HackIos/out/images/umi-uefi-menu-walk.img
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho
W=/mnt/e/Code/HackIos/out/fixtures/launchd-walk.macho

echo "== 1. 指纹 =="
sha256sum "$IMG" "$K" "$W"
ls -la "$IMG"

echo
echo "== 2. 交付档的 stage2 toml（标题/入口名）=="
for f in /home/unixnu/code/UniXNU-main/out/*/stage2/unixnu.toml /home/unixnu/code/UniXNU-main/out/**/unixnu.toml; do
  [ -f "$f" ] || continue
  echo "---- $f"
  grep -nE 'title|name|payload|kernel|launchd' "$f" | head -20
done

echo
echo "== 3. 走查件字节是否原样进卷（在镜像里搜件的 __text 首 32 字节）=="
head -c 32 "$W" | od -An -tx1 | tr -d ' \n' > /tmp/wsig
S=$(cat /tmp/wsig)
echo "fixture head=$S"
off=$(od -An -tx1 -v "$IMG" | tr -d ' \n' | grep -ob "$S" | head -1 | cut -d: -f1)
echo "在镜像中的字节偏移命中=$off"

echo
echo "== 4. 内核 EL0 IN/OUT 串在镜像里命中次数 =="
for pat in 'EL0 IN svc=' 'EL0 OUT svc=' 'M-WALK'; do
  printf '%-16s %s\n' "$pat" "$(grep -aoc "$pat" "$IMG" 2>/dev/null)"
done

echo
echo "== 5. pack 自检记录 =="
tail -25 /mnt/e/Code/HackIos/out/probes/pack-check.txt 2>/dev/null || echo NO-PACK-CHECK
echo "== done $(date -u +%FT%TZ)"
