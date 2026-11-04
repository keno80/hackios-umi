#!/bin/bash
# 接 s40：上游有 scripts/unixnu/udif.py（纯 Python，非 macOS 宿主解 DMG 的官方通路）。
# 本文件只要三张图：
#   1) scripts/unixnu 包的全貌 + 每个模块首行 docstring（找 APFS/bdev/挂载读者）；
#   2) 全 scripts 里 'bvxn|bdev|cryptex|apfs|UDIF' 的出处，锁定 DMG→文件的真正解码器；
#   3) 到底哪个脚本往 os-mount / systemos-mount 里写文件（=我们要复刻的那一步），它跑在哪种宿主上。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s41-upstream-dmg-recipe.txt 2>&1
U=/home/unixnu/code/UniXNU-main

echo "== 1. scripts/unixnu 包全貌 =="
ls -l "$U/scripts/unixnu/" 2>&1
echo "--- 每个模块的第一行 docstring ---"
for f in "$U"/scripts/unixnu/*.py; do
  printf '%-28s ' "$(basename "$f")"
  python3 - "$f" <<'PY'
import ast, sys
d = ast.parse(open(sys.argv[1]).read())
print((ast.get_docstring(d) or '(无 docstring)').split('\n')[0][:200])
PY
done

echo
echo "== 2. bvxn / bdev / cryptex / apfs / UDIF 的出处 =="
grep -rn -E "bvxn|bvxh|bdev|BLOCK_DEV|cryptex|Cryptex" "$U/scripts" 2>/dev/null | grep -v '\.pyc' | head -40
echo "--- apfs 相关 ---"
grep -rln -iE 'apfs' "$U/scripts" 2>/dev/null | head -30

echo
echo "== 3. 谁往 os-mount / systemos-mount 写东西 =="
grep -rn -E "os-mount|systemos-mount" "$U/scripts" 2>/dev/null | grep -viE 'read|require|assert' | head -30
echo "--- 这些脚本里的 mkdir/copy/write 证据 ---"
for f in $(grep -rl -E "os-mount|systemos-mount" "$U/scripts" 2>/dev/null | head -6); do
  echo "### $f"
  grep -nE "mkdir|copy|copytree|write_bytes|extractall|mount|hdiutil|subprocess" "$f" | head -12
done

echo
echo "== 4. udif.py 全文 =="
cat -n "$U/scripts/unixnu/udif.py" 2>/dev/null | head -200
