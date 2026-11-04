#!/bin/bash
# 补丁名靠 z 的个数定重放顺序。r18 查每个文件的前缀 z 数，确认新片排在最后（dry-run 是在全量重放后的树上做的，
# 排最后才和验收时的锚点状态一致）。同时把 29z 改成比 28z 更多的 z。
set -u
O=/mnt/e/Code/HackIos/out/probes/r18-patch-order.txt
: > "$O"; exec >>"$O" 2>&1
DEV=/home/unixnu/code/UniXNU-umi/patches/umi-xnu
ARCH=/mnt/e/Code/HackIos/patches/umi-xnu

echo "== 1. 现有 z 前缀长度（重放按文件名升序）=="
for f in "$DEV"/*.patch; do
  b=$(basename "$f")
  z=${b%%[^z]*}
  printf '%2d  %s\n' "${#z}" "$b"
done | sort -n

echo
echo "== 2. 最长 z 数 =="
MAX=$(for f in "$DEV"/*.patch; do b=$(basename "$f"); z=${b%%[^z]*}; echo "${#z}"; done | sort -n | tail -1)
echo "MAX=$MAX"

echo
echo "== 3. 新片重命名为 MAX+1 =="
for d in "$DEV" "$ARCH"; do
  old=$(ls "$d"/z*-umi-mach-dedupe.patch 2>/dev/null | head -1)
  [ -n "$old" ] || { echo "NO-MACH-PATCH in $d"; continue; }
  pref=$(printf '%0*s' "$((MAX+1))" '' | tr ' ' z)
  mv "$old" "$d/$pref-umi-mach-dedupe.patch"
  ls -la "$d/$pref-umi-mach-dedupe.patch"
  sha256sum "$d/$pref-umi-mach-dedupe.patch"
  printf 'CR=%s\n' "$(tr -dc '\r' < "$d/$pref-umi-mach-dedupe.patch" | wc -c)"
done

echo
echo "== 4. 重放顺序复核 =="
ls "$DEV" | grep '^z' | awk '{n=length($0); c=0; for(i=1;i<=n;i++){ch=substr($0,i,1); if(ch=="z") c++; else break} print c, $0}' | sort -n | tail -6
echo "== done $(date -u +%FT%TZ)"
