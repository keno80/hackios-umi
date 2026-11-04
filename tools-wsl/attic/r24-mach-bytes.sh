#!/bin/bash
# R 步之十五：这台 WSL 的 objdump 没有 aarch64 target、otool 的 llvm 反汇编器又缺失，
# 那就用「字节等价」做静态闸：用同一个 clang 把 `mov x16, #-N` 和 `sub x16, xzr, #N` 各编一遍，
# 若两句话的机器码一模一样，就证明 x16 里真是 -N（sub 从 XZR 出来必然是 0-N）。
# 再拿这段机器码回查走查件，9 发 mach 号一发都不能少。
set -u
O=/mnt/e/Code/HackIos/out/probes/r24-mach-bytes.txt
: > "$O"; exec >>"$O" 2>&1
source /usr/local/bin/unixnu-env 2>/dev/null
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
CLT=$TC/CommandLineTools/usr
F=/mnt/e/Code/HackIos/out/fixtures/launchd-walk.macho
W=/tmp/fx-bytes
rm -rf "$W"; mkdir -p "$W"

echo "== 0. 有没有现成的 aarch64 objdump（有的话更直观）=="
for c in aarch64-linux-gnu-objdump objdump; do
  printf '%s: %s\n' "$c" "$(command -v $c || echo NONE)"
done

echo
echo "== 1. 字节等价验证（以 -28 为例）=="
cat > "$W/mov.s" <<'S'
  mov x16, #-28
  svc #0x80
S
cat > "$W/sub.s" <<'S'
  sub x16, xzr, #28
  svc #0x80
S
"$CLT/bin/clang" -target arm64-apple-ios17.0 -isysroot "$TC/../" -c "$W/mov.s" -o "$W/mov.o" 2>"$W/mov.err" || \
  "$CLT/bin/clang" -target arm64-apple-ios17.0 -c "$W/mov.s" -o "$W/mov.o" 2>>"$W/mov.err"
"$CLT/bin/clang" -target arm64-apple-ios17.0 -isysroot "$TC/../" -c "$W/sub.s" -o "$W/sub.o" 2>"$W/sub.err" || \
  "$CLT/bin/clang" -target arm64-apple-ios17.0 -c "$W/sub.s" -o "$W/sub.o" 2>>"$W/sub.err"
echo "--- mov 版："
"$CLT/bin/otool" -t "$W/mov.o" 2>&1 | tail -3
echo "--- sub 版："
"$CLT/bin/otool" -t "$W/sub.o" 2>&1 | tail -3
echo "--- clang stderr(mov)："; cat "$W/mov.err" 2>/dev/null | head -4

MOVW=$("$CLT/bin/otool" -t "$W/mov.o" 2>/dev/null | awk 'NR>1 {print $1; exit}')
SUBW=$("$CLT/bin/otool" -t "$W/sub.o" 2>/dev/null | awk 'NR>1 {print $1; exit}')
echo "MOV=$MOVW SUB=$SUBW"
[ -n "$MOVW" ] && [ "$MOVW" = "$SUBW" ] && echo "BYTES-EQUAL（x16 确为 -28）" || echo "BYTES-DIFFER 需要人工看"

echo
echo "== 2. 走查件里 9 个 mach 号的机器码是否都在 =="
for n in 28 29 27 26 89 16 19 18 31; do
  cat > "$W/r.s" <<S
  sub x16, xzr, #$n
  svc #0x80
S
  "$CLT/bin/clang" -target arm64-apple-ios17.0 -c "$W/r.s" -o "$W/r.o" 2>/dev/null
  w=$("$CLT/bin/otool" -t "$W/r.o" 2>/dev/null | awk 'NR>1 {print toupper($1); exit}')
  c=$("$CLT/bin/otool" -t "$F" 2>/dev/null | grep -ic "$w")
  printf 'x16=-%-4s code=%s 件内出现=%s\n' "$n" "${w:-ERR}" "$c"
done

echo
echo "== 3. 件里 __text 总指令字数（应≈svc 发数×若干）=="
"$CLT/bin/otool" -t "$F" 2>/dev/null | awk 'NR>1' | wc -l
echo "== done $(date -u +%FT%TZ)"
