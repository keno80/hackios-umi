#!/bin/bash
# K 步收尾：确认真机菜单标题真是 K-EL0（照片里靠它认档），从 stage2 的 toml 与交付镜像两处各证一次。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/k11-title-check.txt
: > "$OUT"
exec >>"$OUT" 2>&1

TOML=/home/unixnu/code/umi-work-pin/out/umi/xnu/stage2/EFI/UniXNU/unixnu.toml
IMG=/mnt/e/Code/HackIos/out/images/umi-uefi-menu-el0.img

echo "== 1. stage2 的 toml =="
ls -la "$TOML" 2>/dev/null || echo "NO-TOML-AT-STAGE2"
grep -n 'title\|args\|initrd\|path' "$TOML" 2>/dev/null

echo
echo "== 2. 交付镜像里直接找标题串 =="
for s in 'K-EL0 Mi 10 8G' 'Mi 10 8G - MOCKFS+PROBE' 'rd=md0'; do
  printf '%-26s hit=%s\n' "$s" "$(strings -a -t none "$IMG" 2>/dev/null | grep -c -F "$s")"
done
echo
echo "== 3. 镜像里标题上下文 =="
strings -a "$IMG" | grep -n -F 'K-EL0' | head -5
echo done
