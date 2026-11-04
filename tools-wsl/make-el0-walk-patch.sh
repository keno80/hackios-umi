#!/bin/bash
# 落成 umi-el0-walk 补丁（23z）：把 EL0 unix 打点从「整条链只打第一条」升级成
# 「每个 syscall 号各打一次，进入打 pc、返回打 x0」，这样走查 fixture 的每一步都能在屏上读出来。
# 基线必须是 22z 应用后的文本（重放按文件名排序，23z 排在 22z 之后），所以锚点取自当前 .cache/xnu-work。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/m-make-walk-patch.txt
: > "$OUT"
exec >>"$OUT" 2>&1

WS=/home/unixnu/code/umi-work-pin
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work
DEV=/home/unixnu/code/UniXNU-umi
ARCH=/mnt/e/Code/HackIos/patches/umi-xnu
NAME=zzzzzzzzzzzzzzzzzzzzzzz-umi-el0-walk.patch

echo "== 0. 基线必须已含 22z（否则 23z 的锚点找不到）=="
grep -c 'umi_el0_unix_done' "$X/osfmk/arm64/sleh.c"
grep -c 'unix_syscall(state, thread, p);' "$X/osfmk/arm64/sleh.c"

echo
echo "== 1. 生成 =="
WORK=$(mktemp -d)
rel=osfmk/arm64/sleh.c
mkdir -p "$WORK/a/$(dirname "$rel")" "$WORK/b/$(dirname "$rel")"
cp "$X/$rel" "$WORK/a/$rel"
cp "$X/$rel" "$WORK/b/$rel"

python3 - "$WORK" <<'PY'
import pathlib, sys

work = pathlib.Path(sys.argv[1])
rel = "osfmk/arm64/sleh.c"
p = work / "b" / rel
text = p.read_text()

pairs = [
    (
        "\t\t\tstatic int umi_el0_unix_done;\n",
        "\t\t\tstatic uint8_t umi_el0_unix_seen[512];\n",
    ),
    (
        "\t\t\tif (!umi_el0_unix_done) {\n",
        "\t\t\tif (trap_no >= 0 && trap_no < (int)sizeof(umi_el0_unix_seen) &&\n"
        "\t\t\t    !umi_el0_unix_seen[trap_no]) {\n",
    ),
    (
        "\t\t\t\tumi_el0_unix_done = 1;\n",
        "\t\t\t\tumi_el0_unix_seen[trap_no] = 1;\n",
    ),
    (
        '\t\t\t\t    "EL0 UNIX svc=%d pc=0x%llx", trap_no,\n',
        '\t\t\t\t    "EL0 IN svc=%d pc=0x%llx", trap_no,\n',
    ),
    (
        "\t\tunix_syscall(state, thread, p);\n",
        "\t\tunix_syscall(state, thread, p);\n"
        "\t\t/* UMI bring-up: the return value is the only on-panel evidence of whether a\n"
        "\t\t * given unix syscall actually completed; a missing OUT line for the last IN\n"
        "\t\t * line is exactly the syscall that stopped the walk. */\n"
        "\t\t{\n"
        "\t\t\tstatic uint8_t umi_el0_out_seen[512];\n"
        "\n"
        "\t\t\tif (trap_no >= 0 && trap_no < (int)sizeof(umi_el0_out_seen) &&\n"
        "\t\t\t    !umi_el0_out_seen[trap_no]) {\n"
        "\t\t\t\tchar umi_msg[96];\n"
        "\n"
        "\t\t\t\tumi_el0_out_seen[trap_no] = 1;\n"
        "\t\t\t\t(void)snprintf(umi_msg, sizeof(umi_msg),\n"
        '\t\t\t\t    "EL0 OUT svc=%d r0=0x%llx", trap_no,\n'
        "\t\t\t\t    (unsigned long long)saved_state64(state)->x[0]);\n"
        "\t\t\t\tboot_progress_stage(umi_msg);\n"
        "\t\t\t}\n"
        "\t\t}\n",
    ),
]

for i, (old, new) in enumerate(pairs):
    n = text.count(old)
    assert n == 1, (i, "anchor-count", n)
    text = text.replace(old, new)
p.write_text(text)
print("edited", rel)
PY
[ $? -eq 0 ] || { echo "EDIT-FAIL"; rm -rf "$WORK"; exit 1; }

echo
echo "== 2. diff =="
{
  echo "--- a/$rel"
  echo "+++ b/$rel"
  ( cd "$WORK" && diff -u "a/$rel" "b/$rel" ) | tail -n +3
} > "$WORK/body.diff"
cat "$WORK/body.diff"

echo
echo "== 3. 落盘 =="
cp "$WORK/body.diff" "$DEV/patches/umi-xnu/$NAME"
cp "$WORK/body.diff" "$ARCH/$NAME"
ls -la "$DEV/patches/umi-xnu/$NAME" "$ARCH/$NAME"
sha256sum "$DEV/patches/umi-xnu/$NAME" "$ARCH/$NAME"

echo
echo "== 4. dry-run 能否打上（基线含 22z）=="
( cd "$X" && patch -p1 --dry-run < "$DEV/patches/umi-xnu/$NAME" ) && echo "DRYRUN-OK" || echo "DRYRUN-FAIL"

echo
echo "== 5. CRLF 检查 =="
for f in "$DEV/patches/umi-xnu/$NAME" "$ARCH/$NAME"; do
  printf '%s CR=%s\n' "$f" "$(tr -dc '\r' < "$f" | wc -c)"
done

echo
echo "== 6. 重放顺序确认（23z 必须紧跟 22z 之后）=="
ls "$DEV/patches/umi-xnu/" | grep '^z' | sort | tail -3
rm -rf "$WORK"
echo done
