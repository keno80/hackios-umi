#!/bin/bash
# 落成 umi-boot-stage 补丁：把 boot_progress_stage 的 no-op 桩改接画屏器。
set -eu
OUT=/mnt/e/Code/HackIos/out/f-make-patch.txt
: > "$OUT"
exec >>"$OUT" 2>&1

WS=/home/unixnu/code/umi-work-pin
TREE=$WS/out/umi-xnu/umi/tree
X=$TREE/.cache/xnu-work
DEV=/home/unixnu/code/UniXNU-umi
HDR=osfmk/kern/boot_progress.h
NAME=zzzzzzzzzzzzzzzzzzzz-umi-boot-stage.patch

echo "== umi-xnu 补丁的重放机制 =="
grep -rn 'umi-xnu' $TREE/scripts/build-xnu-4k-baseline.sh 2>/dev/null | head -10
grep -rn 'patch \|git apply' $TREE/scripts/build-xnu-4k-baseline.sh 2>/dev/null | head -10

echo
echo "== 现有 boot_progress.h 的 #else 段 =="
sed -n '/^#else/,/^#endif/p' $X/$HDR

echo
echo "== 生成新文件 =="
WORK=$(mktemp -d)
cp $X/$HDR $WORK/a.h
python3 - "$X/$HDR" "$WORK/b.h" <<'PY'
import sys, pathlib
src, dst = sys.argv[1], sys.argv[2]
text = pathlib.Path(src).read_text()
old = '#else\n#define boot_progress_init() ((void)0)'
new = ('#else\n/* UMI bring-up: the boot-progress archive is not linked on this board, '
       'so stage strings still have to reach the on-screen painter. */\n'
       'extern void umi_screen_text(const char *);\n'
       '#define boot_progress_init() ((void)0)')
assert text.count(old) == 1, ('anchor1', text.count(old))
text = text.replace(old, new)
old2 = '#define boot_progress_stage(s) ((void)0)'
assert text.count(old2) == 1, ('anchor2', text.count(old2))
text = text.replace(old2, '#define boot_progress_stage(s) umi_screen_text(s)')
pathlib.Path(dst).write_text(text)
print('edited ok')
PY

mkdir -p $WORK/a/osfmk/kern $WORK/b/osfmk/kern
cp $WORK/a.h $WORK/a/$HDR
cp $WORK/b.h $WORK/b/$HDR
( cd $WORK && diff -u a/$HDR b/$HDR ) | sed "1s|\ta/|$WORK/a/|; 2s|\tb/|$WORK/b/|" > $WORK/body.diff || true
echo "--- raw diff ---"
cat $WORK/body.diff

{
  echo "--- a/$HDR"
  echo "+++ b/$HDR"
  tail -n +3 $WORK/body.diff
} > $DEV/patches/umi-xnu/$NAME

echo
echo "== 补丁文件 =="
ls -la $DEV/patches/umi-xnu/$NAME
cat $DEV/patches/umi-xnu/$NAME

echo
echo "== dry-run 能否打上 =="
( cd $X && patch -p1 --dry-run < $DEV/patches/umi-xnu/$NAME ) && echo "DRYRUN-OK" || echo "DRYRUN-FAIL"
echo
echo "== CRLF 检查 =="
if grep -q $'\r' $DEV/patches/umi-xnu/$NAME; then echo HAS-CR; else echo LF-ONLY; fi
rm -rf $WORK
