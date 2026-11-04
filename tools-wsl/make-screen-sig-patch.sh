#!/bin/bash
# 落成 umi-screen-sig 补丁：面板去重从「消息指针」改成「消息内容哈希」。
# 原因：探针普遍把 snprintf 结果放在同一个栈缓冲里，多个不同 svc 号的行共用一个地址，
#       旧逻辑把它们当成重复，只画一行加个 xN 计数——23z 的 IN/OUT 序列会被压掉一半。
# 基线取构建真正消费的 .cache/xnu-work（已含 17z…23z），产物同时落 ext4 设备仓与 Windows 归档。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/m-make-screen-sig-patch.txt
: > "$OUT"
exec >>"$OUT" 2>&1

WS=/home/unixnu/code/umi-work-pin
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work
DEV=/home/unixnu/code/UniXNU-umi
ARCH=/mnt/e/Code/HackIos/patches/umi-xnu
NAME=zzzzzzzzzzzzzzzzzzzzzzzz-umi-screen-sig.patch
REL=osfmk/console/video_console.c

echo "== 0. 基线在不在 =="
ls -la "$X/$REL" || { echo "NO-BASELINE $REL"; exit 1; }

echo
echo "== 1. 生成 =="
WORK=$(mktemp -d)
mkdir -p "$WORK/a/osfmk/console" "$WORK/b/osfmk/console"
cp "$X/$REL" "$WORK/a/$REL"
cp "$X/$REL" "$WORK/b/$REL"

python3 - "$WORK" <<'PY'
import pathlib, sys

work = pathlib.Path(sys.argv[1])
rel = "osfmk/console/video_console.c"
p = work / "b" / rel
text = p.read_text()

pairs = [
    (
        "void\n"
        "umi_screen_text(const char *umi_message)\n"
        "{\n"
        "\tif (umi_scr_halted || umi_scr_live() == 0) {\n",
        "/*\n"
        "\t * UMI bring-up: the repeat signature below is a content hash, not the\n"
        "\t * address of the message. Probes build their text in one shared stack buffer,\n"
        "\t * so comparing pointers collapsed genuinely different lines into a single\n"
        "\t * counted line. Identical text still folds, so spin loops stay quiet.\n"
        "\t */\n"
        "static unsigned long\n"
        "umi_scr_text_hash(const char *umi_text)\n"
        "{\n"
        "\tunsigned long umi_hash = 14695981039346656037UL;\n"
        "\n"
        "\tif (umi_text == NULL) {\n"
        "\t\treturn 0;\n"
        "\t}\n"
        "\tfor (; *umi_text != '\\0'; umi_text++) {\n"
        "\t\tumi_hash = (umi_hash ^ (unsigned long) (unsigned char) *umi_text) *\n"
        "\t\t    1099511628211UL;\n"
        "\t}\n"
        "\treturn umi_hash;\n"
        "}\n"
        "\n"
        "void\n"
        "umi_screen_text(const char *umi_message)\n"
        "{\n"
        "\tif (umi_scr_halted || umi_scr_live() == 0) {\n",
    ),
    (
        "\tif (umi_scr_sig_kind == 2 && umi_scr_sig_a == (unsigned long) umi_message) {\n",
        "\tif (umi_scr_sig_kind == 2 && umi_scr_sig_a == umi_scr_text_hash(umi_message)) {\n",
    ),
    (
        "\tumi_scr_sig_a = (unsigned long) umi_message;\n",
        "\tumi_scr_sig_a = umi_scr_text_hash(umi_message);\n",
    ),
]

for i, (old, new) in enumerate(pairs):
    n = text.count(old)
    assert n == 1, (rel, i, "anchor-count", n)
    text = text.replace(old, new)

p.write_text(text)
print("edited", rel)
PY
[ $? -eq 0 ] || { echo "EDIT-FAIL"; rm -rf "$WORK"; exit 1; }

echo
echo "== 2. diff =="
{
  echo "--- a/$REL"
  echo "+++ b/$REL"
  ( cd "$WORK" && diff -u "a/$REL" "b/$REL" ) | tail -n +3
} | tee "$WORK/body.diff"

echo
echo "== 3. 落盘 =="
cp "$WORK/body.diff" "$DEV/patches/umi-xnu/$NAME"
cp "$WORK/body.diff" "$ARCH/$NAME"
ls -la "$DEV/patches/umi-xnu/$NAME" "$ARCH/$NAME"
sha256sum "$DEV/patches/umi-xnu/$NAME" "$ARCH/$NAME"

echo
echo "== 4. dry-run 能否打上（基线含 23z）=="
( cd "$X" && patch -p1 --dry-run < "$DEV/patches/umi-xnu/$NAME" ) && echo "DRYRUN-OK" || echo "DRYRUN-FAIL"

echo
echo "== 5. CRLF 检查 =="
for f in "$DEV/patches/umi-xnu/$NAME" "$ARCH/$NAME"; do
  printf '%s CR=%s\n' "$f" "$(tr -dc '\r' < "$f" | wc -c)"
done

echo
echo "== 6. 重放顺序确认（24z 必须紧跟 23z 之后）=="
ls "$DEV/patches/umi-xnu/" | grep '^z' | sort | tail -4
rm -rf "$WORK"
echo done
