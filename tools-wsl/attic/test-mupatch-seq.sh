#!/bin/bash
set -u
M=/home/unixnu/code/Mu_Basecore
D=/home/unixnu/code/uefi-umi-b
P=$D/Resources/MuPatches
echo "== 按 board.toml 顺序串行 apply"
for p in Gic-Spurious Mac-Bash3 Dxe-Trace Display-Services-Trace; do
  if git -C "$M" apply "$P/$p.patch" 2>/tmp/applyerr; then echo "  applied  $p"; else echo "  FAIL     $p: $(head -2 /tmp/applyerr | tr '\n' ' ')"; fi
done
echo "  dirty files: $(git -C "$M" status --porcelain | wc -l)"
git -C "$M" status --porcelain | sed 's/^/    /'
echo "== 立刻全部反向回滚"
for p in Display-Services-Trace Dxe-Trace Mac-Bash3 Gic-Spurious; do
  git -C "$M" apply --reverse "$P/$p.patch" 2>/dev/null && echo "  reverted $p" || echo "  FAIL-REVERSE $p"
done
echo "  dirty files after rollback: $(git -C "$M" status --porcelain | wc -l)"
echo DONE
