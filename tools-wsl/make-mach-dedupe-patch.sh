#!/bin/bash
# 落成 umi-mach-dedupe 补丁（29z）：sleh.c 的 mach 侧 EL0 探针是 `static int umi_el0_mach_done`
# ——整条 boot 只打第一行，走查件打多发 mach trap 时屏上看不见后面的。这里对齐 23z 在 unix 侧的做法：
# 按 trap 号去重，进 IN、出 OUT 各一张表；号 = -trap_no，越界（>=128，即 mach_trap_table 表长）直接不打。
# 基线是 22z+23z 已重放后的 .cache/xnu-work 文本，锚点全部逐字取自当前文件。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/m-make-mach-dedupe.txt
: > "$OUT"
exec >>"$OUT" 2>&1

WS=/home/unixnu/code/umi-work-pin
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work
DEV=/home/unixnu/code/UniXNU-umi
ARCH=/mnt/e/Code/HackIos/patches/umi-xnu
NAME=zzzzzzzzzzzzzzzzzzzzzzzz-umi-mach-dedupe.patch

echo "== 0. 基线必须已含 22z/23z 的 mach 原块 =="
grep -c 'umi_el0_mach_done' "$X/osfmk/arm64/sleh.c"
grep -c 'mach_syscall(state);' "$X/osfmk/arm64/sleh.c"
grep -c 'umi_el0_out_seen' "$X/osfmk/arm64/sleh.c"

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
        "\t\t\tstatic int umi_el0_mach_done;\n",
        "\t\t\tstatic uint8_t umi_el0_mach_seen[128]; /* == MACH_TRAP_TABLE_COUNT */\n"
        "\t\t\tint umi_mach_no = -trap_no;\n",
    ),
    (
        "\t\t\tif (!umi_el0_mach_done) {\n",
        "\t\t\tif (umi_mach_no >= 0 && umi_mach_no < (int)sizeof(umi_el0_mach_seen) &&\n"
        "\t\t\t    !umi_el0_mach_seen[umi_mach_no]) {\n",
    ),
    (
        "\t\t\t\tumi_el0_mach_done = 1;\n",
        "\t\t\t\tumi_el0_mach_seen[umi_mach_no] = 1;\n",
    ),
    (
        '\t\t\t\t    "EL0 MACH svc=%d pc=0x%llx", trap_no,\n',
        '\t\t\t\t    "EL0 IN svc=%d pc=0x%llx", trap_no,\n',
    ),
    (
        "\t\tmach_syscall(state);\n",
        "\t\tmach_syscall(state);\n"
        "\t\t/* UMI bring-up: same evidence contract as the unix side -- the IN line proves\n"
        "\t\t * EL0 reached this trap, the OUT line proves the mach handler actually returned.\n"
        "\t\t * Numbers are negative here because mach traps are -table_index in x16. */\n"
        "\t\t{\n"
        "\t\t\tstatic uint8_t umi_el0_mach_out_seen[128]; /* == MACH_TRAP_TABLE_COUNT */\n"
        "\t\t\tint umi_mach_no = -trap_no;\n"
        "\n"
        "\t\t\tif (umi_mach_no >= 0 && umi_mach_no < (int)sizeof(umi_el0_mach_out_seen) &&\n"
        "\t\t\t    !umi_el0_mach_out_seen[umi_mach_no]) {\n"
        "\t\t\t\tchar umi_msg[96];\n"
        "\n"
        "\t\t\t\tumi_el0_mach_out_seen[umi_mach_no] = 1;\n"
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
echo "== 2. mach 侧要用 MACH_TRAP_TABLE_COUNT，确认 sleh.c 已含该宏 =="
grep -n "syscall_sw.h\|MACH_TRAP_TABLE_COUNT" "$X/osfmk/arm64/sleh.c" | head -5
grep -rn "include.*mach/mach_traps.h\|include.*kern/syscall_sw.h" "$X/osfmk/arm64/sleh.c" | head -5

echo
echo "== 3. diff =="
{
  echo "--- a/$rel"
  echo "+++ b/$rel"
  ( cd "$WORK" && diff -u "a/$rel" "b/$rel" ) | tail -n +3
} > "$WORK/body.diff"
cat "$WORK/body.diff"

echo
echo "== 4. 落盘 =="
cp "$WORK/body.diff" "$DEV/patches/umi-xnu/$NAME"
cp "$WORK/body.diff" "$ARCH/$NAME"
ls -la "$DEV/patches/umi-xnu/$NAME" "$ARCH/$NAME"
sha256sum "$DEV/patches/umi-xnu/$NAME" "$ARCH/$NAME"

echo
echo "== 5. dry-run 能否打上 =="
( cd "$X" && patch -p1 --dry-run < "$DEV/patches/umi-xnu/$NAME" ) && echo "DRYRUN-OK" || echo "DRYRUN-FAIL"

echo
echo "== 6. CRLF 检查 =="
for f in "$DEV/patches/umi-xnu/$NAME" "$ARCH/$NAME"; do
  printf '%s CR=%s\n' "$f" "$(tr -dc '\r' < "$f" | wc -c)"
done

echo
echo "== 7. 重放顺序确认（29z 必须排在 28z 之后）=="
ls "$DEV/patches/umi-xnu/" | grep '^z' | sort | tail -4
rm -rf "$WORK"
echo done
