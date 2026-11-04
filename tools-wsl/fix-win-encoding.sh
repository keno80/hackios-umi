#!/bin/bash
# 把 tools-win 下的 Windows 侧脚本落成 Windows 能正确吃到的字节形态：
#   .ps1  -> UTF-8 with BOM + CRLF（PowerShell 5.1 不读带中文的无 BOM UTF-8）
#   .cmd/.bat -> 纯 ASCII + CRLF
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
OUT=out/probes/win-encoding.txt
mkdir -p out/probes
exec >> "$OUT" 2>&1
echo "==== $(date -Is) ===="
for f in tools-win/*.ps1; do
  [ -f "$f" ] || continue
  tmp=$(mktemp)
  sed 's/\r$//' "$f" | sed 's/$/\r/' > "$tmp.body"
  if head -c 3 "$f" | od -An -tx1 | tr -d ' \n' | grep -q '^efbbbf'; then
    cp "$tmp.body" "$tmp"
  else
    printf '\xef\xbb\xbf' > "$tmp"
    cat "$tmp.body" >> "$tmp"
  fi
  mv "$tmp" "$f"; rm -f "$tmp.body"
  echo "ps1 BOM+CRLF: $f"
done
for f in tools-win/*.cmd tools-win/*.bat; do
  [ -f "$f" ] || continue
  tmp=$(mktemp)
  sed 's/\r$//' "$f" | sed 's/$/\r/' > "$tmp"
  mv "$tmp" "$f"
  echo "cmd CRLF: $f  nonASCII=$(grep -cP '[^\x00-\x7F]' "$f" || true)"
done
echo "-- 校验 --"
for f in tools-win/*.ps1 tools-win/*.cmd tools-win/*.bat; do
  [ -f "$f" ] || continue
  BOM=$(head -c 3 "$f" | od -An -tx1 | tr -d ' \n')
  CRLF=$(awk '/\r$/{n++} END{print n+0}' "$f")
  LINES=$(wc -l < "$f")
  echo "$f bom=$BOM crlf=$CRLF lines=$LINES"
done
echo done
