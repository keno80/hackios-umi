#!/bin/bash
# 落成 umi-el0-probe 补丁：把「launchd 到底 exec 成没成」「真机到底进过用户态没有」打到屏上。
# 基线取构建真正消费的 .cache/xnu-work（已含 21z），产物同时落 ext4 设备仓与 Windows 归档。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/k-make-patch.txt
: > "$OUT"
exec >>"$OUT" 2>&1

WS=/home/unixnu/code/umi-work-pin
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work
DEV=/home/unixnu/code/UniXNU-umi
ARCH=/mnt/e/Code/HackIos/patches/umi-xnu
NAME=zzzzzzzzzzzzzzzzzzzzzz-umi-el0-probe.patch

echo "== 0. 基线在不在 =="
for f in bsd/kern/kern_exec.c bsd/kern/bsd_init.c osfmk/arm64/sleh.c; do
  ls -la "$X/$f" || { echo "NO-BASELINE $f"; exit 1; }
done

echo
echo "== 1. 生成 =="
WORK=$(mktemp -d)
for rel in bsd/kern/kern_exec.c bsd/kern/bsd_init.c osfmk/arm64/sleh.c; do
  mkdir -p "$WORK/a/$(dirname "$rel")" "$WORK/b/$(dirname "$rel")"
  cp "$X/$rel" "$WORK/a/$rel"
  cp "$X/$rel" "$WORK/b/$rel"
done

python3 - "$WORK" <<'PY'
import pathlib, sys

work = pathlib.Path(sys.argv[1])

def edit(rel, pairs):
    p = work / "b" / rel
    text = p.read_text()
    for i, (old, new) in enumerate(pairs):
        n = text.count(old)
        assert n == 1, (rel, i, "anchor-count", n)
        text = text.replace(old, new)
    p.write_text(text)
    print("edited", rel)

# ---- bsd/kern/kern_exec.c：把三级回退的成败从 printf 搬到屏 ----
# snprintf 由 osfmk/kern/misc_protos.h 声明，这棵树里 kern_exec.c 已引过 <libkern/libkern.h>，不再重复加头。
edit("bsd/kern/kern_exec.c", [
    (
        "\terror = ENOENT;\n"
        "\tfor (i = 0; i < sizeof(init_programs) / sizeof(init_programs[0]); i++) {\n"
        '\t\tprintf("load_init_program: attempting to load %s\\n", init_programs[i]);\n'
        "\t\terror = load_init_program_at_path(p, (user_addr_t)scratch_addr, init_programs[i], init_envp);\n"
        "\t\tif (!error) {\n"
        "\t\t\treturn;\n"
        "\t\t} else if (error != ENOENT) {\n"
        '\t\t\tprintf("load_init_program: failed loading %s: errno %d\\n", init_programs[i], error);\n'
        "\t\t}\n"
        "\t}\n",
        "\terror = ENOENT;\n"
        "\t/* UMI bring-up: every one of these outcomes was printf-only, and printf never\n"
        "\t * reaches this panel, so \"load_init_program enter\" as the last line is ambiguous. */\n"
        "\tfor (i = 0; i < sizeof(init_programs) / sizeof(init_programs[0]); i++) {\n"
        "\t\tchar umi_msg[160];\n"
        "\n"
        '\t\t(void)snprintf(umi_msg, sizeof(umi_msg), "INIT try %s", init_programs[i]);\n'
        "\t\tboot_progress_stage(umi_msg);\n"
        '\t\tprintf("load_init_program: attempting to load %s\\n", init_programs[i]);\n'
        "\t\terror = load_init_program_at_path(p, (user_addr_t)scratch_addr, init_programs[i], init_envp);\n"
        "\t\tif (!error) {\n"
        '\t\t\tboot_progress_stage("INIT exec ok");\n'
        "\t\t\treturn;\n"
        "\t\t} else if (error != ENOENT) {\n"
        '\t\t\tprintf("load_init_program: failed loading %s: errno %d\\n", init_programs[i], error);\n'
        "\t\t\t(void)snprintf(umi_msg, sizeof(umi_msg), \"INIT err=%d %s\", error,\n"
        "\t\t\t    init_programs[i]);\n"
        "\t\t\tboot_progress_stage(umi_msg);\n"
        "\t\t}\n"
        "\t}\n",
    ),
])

# ---- bsd/kern/bsd_init.c：load_init_program 返回之后 ----
edit("bsd/kern/bsd_init.c", [
    (
        "\tload_init_program(p);\n"
        "\tlock_trace = 1;\n",
        "\tload_init_program(p);\n"
        '\tboot_progress_stage("INIT returned");\n'
        "\tlock_trace = 1;\n",
    ),
])

# ---- osfmk/arm64/sleh.c：用户态陷入内核的唯一漏斗，mach/unix 各打一次 ----
# sleh.c 顶已引 <kern/boot_progress.h>，snprintf 也已在用（misc_protos.h 声明），所以只插打点、不加头。
# sleh.c:781 的 case ESR_EC_SVC_64 已用 is_user 闸过，所以这里的 EL0 标记是真阳性证据。
edit("osfmk/arm64/sleh.c", [
    (
        "\t\tthread->syscalls_mach++;\n"
        "\t\tmach_syscall(state);\n",
        "\t\tthread->syscalls_mach++;\n"
        "\t\t/* UMI bring-up: one line per flavour, first hit only. This is the only\n"
        "\t\t * positive proof on this panel that EL0 actually executed user code. */\n"
        "\t\t{\n"
        "\t\t\tstatic int umi_el0_mach_done;\n"
        "\n"
        "\t\t\tif (!umi_el0_mach_done) {\n"
        "\t\t\t\tchar umi_msg[96];\n"
        "\n"
        "\t\t\t\tumi_el0_mach_done = 1;\n"
        "\t\t\t\t(void)snprintf(umi_msg, sizeof(umi_msg),\n"
        '\t\t\t\t    "EL0 MACH svc=%d pc=0x%llx", trap_no,\n'
        "\t\t\t\t    (unsigned long long)get_saved_state_pc(state));\n"
        "\t\t\t\tboot_progress_stage(umi_msg);\n"
        "\t\t\t}\n"
        "\t\t}\n"
        "\t\tmach_syscall(state);\n",
    ),
    (
        "\t\tthread->syscalls_unix++;\n"
        "\t\tp = get_bsdthreadtask_info(thread);\n",
        "\t\tthread->syscalls_unix++;\n"
        "\t\t{\n"
        "\t\t\tstatic int umi_el0_unix_done;\n"
        "\n"
        "\t\t\tif (!umi_el0_unix_done) {\n"
        "\t\t\t\tchar umi_msg[96];\n"
        "\n"
        "\t\t\t\tumi_el0_unix_done = 1;\n"
        "\t\t\t\t(void)snprintf(umi_msg, sizeof(umi_msg),\n"
        '\t\t\t\t    "EL0 UNIX svc=%d pc=0x%llx", trap_no,\n'
        "\t\t\t\t    (unsigned long long)get_saved_state_pc(state));\n"
        "\t\t\t\tboot_progress_stage(umi_msg);\n"
        "\t\t\t}\n"
        "\t\t}\n"
        "\t\tp = get_bsdthreadtask_info(thread);\n",
    ),
])
PY
[ $? -eq 0 ] || { echo "EDIT-FAIL"; rm -rf "$WORK"; exit 1; }

echo
echo "== 2. 逐文件 diff =="
: > "$WORK/body.diff"
for rel in bsd/kern/kern_exec.c bsd/kern/bsd_init.c osfmk/arm64/sleh.c; do
  {
    echo "--- a/$rel"
    echo "+++ b/$rel"
    ( cd "$WORK" && diff -u "a/$rel" "b/$rel" ) | tail -n +3
  } >> "$WORK/body.diff" || true
done
cat "$WORK/body.diff"

echo
echo "== 3. 落盘 =="
cp "$WORK/body.diff" "$DEV/patches/umi-xnu/$NAME"
cp "$WORK/body.diff" "$ARCH/$NAME"
ls -la "$DEV/patches/umi-xnu/$NAME" "$ARCH/$NAME"

echo
echo "== 4. dry-run 能否打上 =="
( cd "$X" && patch -p1 --dry-run < "$DEV/patches/umi-xnu/$NAME" ) && echo "DRYRUN-OK" || echo "DRYRUN-FAIL"

echo
echo "== 5. CRLF 检查 =="
for f in "$DEV/patches/umi-xnu/$NAME" "$ARCH/$NAME"; do
  printf '%s CR=%s\n' "$f" "$(tr -dc '\r' < "$f" | wc -c)"
done

echo
echo "== 6. 新文件里的探针行 =="
grep -n 'boot_progress_stage(umi_msg)\|boot_progress_stage("INIT' \
  "$WORK/b/bsd/kern/kern_exec.c" "$WORK/b/bsd/kern/bsd_init.c" "$WORK/b/osfmk/arm64/sleh.c"
echo
echo "== 7. 重放顺序确认（22z 必须排在 21z 之后）=="
ls "$DEV/patches/umi-xnu/" | grep '^z' | sort | tail -4
rm -rf "$WORK"
echo done
