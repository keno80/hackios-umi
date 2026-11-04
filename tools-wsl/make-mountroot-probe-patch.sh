#!/bin/bash
# 落成 umi-mountroot-probe 补丁：把挂根失败的判据从 printf（上不了屏）搬到 boot_progress_stage（上屏）。
# 基线取构建真正消费的 .cache/xnu-work，产物同时落 ext4 设备仓与 Windows 归档。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/i-make-patch.txt
: > "$OUT"
exec >>"$OUT" 2>&1

WS=/home/unixnu/code/umi-work-pin
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work
DEV=/home/unixnu/code/UniXNU-umi
ARCH=/mnt/e/Code/HackIos/patches/umi-xnu
NAME=zzzzzzzzzzzzzzzzzzzzz-umi-mountroot-probe.patch

echo "== 0. 基线在不在 =="
ls -la "$X/bsd/kern/bsd_init.c" "$X/bsd/vfs/vfs_subr.c" || { echo "NO-BASELINE"; exit 1; }

echo
echo "== 1. 生成 =="
WORK=$(mktemp -d)
mkdir -p "$WORK/a/bsd/kern" "$WORK/a/bsd/vfs" "$WORK/b/bsd/kern" "$WORK/b/bsd/vfs"
cp "$X/bsd/kern/bsd_init.c" "$WORK/a/bsd/kern/"
cp "$X/bsd/vfs/vfs_subr.c" "$WORK/a/bsd/vfs/"
cp "$WORK/a/bsd/kern/bsd_init.c" "$WORK/b/bsd/kern/"
cp "$WORK/a/bsd/vfs/vfs_subr.c" "$WORK/b/bsd/vfs/"

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

# ---- bsd/kern/bsd_init.c ----
edit("bsd/kern/bsd_init.c", [
    (
        "#include <kern/boot_progress.h>\n",
        "#include <kern/boot_progress.h>\n#include <libkern/libkern.h>\t/* UMI bring-up probe: snprintf */\n",
    ),
    (
        "\t/* Mount the root file system. */\n\twhile (TRUE) {\n",
        "\t/* Mount the root file system. */\n"
        "\t/* UMI bring-up: PE_boot_args() is the only place the loader's rd= can be\n"
        "\t * checked, and printf() never reaches this panel. */\n"
        "\t{\n"
        "\t\tchar umi_msg[200];\n"
        "\t\tchar umi_cmd[160];\n"
        "\t\tconst char *umi_args = (const char *)PE_boot_args();\n"
        "\n"
        "\t\t(void)strlcpy(umi_cmd, (umi_args != NULL) ? umi_args : \"(null)\",\n"
        "\t\t    sizeof(umi_cmd));\n"
        "\t\t(void)snprintf(umi_msg, sizeof(umi_msg), \"CMDLINE %s\", umi_cmd);\n"
        "\t\tboot_progress_stage(umi_msg);\n"
        "\t}\n"
        "\twhile (TRUE) {\n",
    ),
    (
        "\t\tprintf(\"cannot mount root, errno = %d\\n\", err);\n"
        "\t}\n",
        "\t\tprintf(\"cannot mount root, errno = %d\\n\", err);\n"
        "\t\t{\n"
        "\t\t\tchar umi_msg[160];\n"
        "\n"
        "\t\t\t(void)snprintf(umi_msg, sizeof(umi_msg),\n"
        "\t\t\t    \"MOUNTFAIL err=%d rootdev=0x%x rd=%s\", err,\n"
        "\t\t\t    (unsigned int)rootdev, (rootdevice[0] != '\\0') ? rootdevice : \"(empty)\");\n"
        "\t\t\tboot_progress_stage(umi_msg);\n"
        "\t\t}\n"
        "\t}\n",
    ),
    (
        "\t\tflags = 0;\n"
        "\t}\n"
        "\n"
        "#if CONFIG_NETBOOT\n",
        "\t\tflags = 0;\n"
        "\t}\n"
        "\n"
        "\t/* UMI bring-up: setconf() is the only writer of rootdev before the first\n"
        "\t * bdevvp(), and its fallback silently renames the root to sd0a. */\n"
        "\t{\n"
        "\t\tchar umi_msg[160];\n"
        "\n"
        "\t\t(void)snprintf(umi_msg, sizeof(umi_msg),\n"
        "\t\t    \"SETCONF iombr=%d rootdev=0x%x rd=%s\", (int)err,\n"
        "\t\t    (unsigned int)rootdev, (rootdevice[0] != '\\0') ? rootdevice : \"(empty)\");\n"
        "\t\tboot_progress_stage(umi_msg);\n"
        "\t}\n"
        "\n"
        "#if CONFIG_NETBOOT\n",
    ),
])

# ---- bsd/vfs/vfs_subr.c ----
edit("bsd/vfs/vfs_subr.c", [
    (
        "#include <kern/assert.h>\n",
        "#include <kern/assert.h>\n"
        "#include <kern/boot_progress.h>\t/* UMI bring-up probe: stage strings reach the panel */\n"
        "#include <libkern/libkern.h>\t/* UMI bring-up probe: snprintf */\n",
    ),
    (
        "\tif ((error = bdevvp(rootdev, &rootvp))) {\n"
        "\t\tprintf(\"vfs_mountroot: can't setup bdevvp\\n\");\n",
        "\tif ((error = bdevvp(rootdev, &rootvp))) {\n"
        "\t\tprintf(\"vfs_mountroot: can't setup bdevvp\\n\");\n"
        "\t\t{\n"
        "\t\t\tchar umi_msg[128];\n"
        "\n"
        "\t\t\t(void)snprintf(umi_msg, sizeof(umi_msg), \"MR bdevvp=%d rootdev=0x%x\",\n"
        "\t\t\t    error, (unsigned int)rootdev);\n"
        "\t\t\tboot_progress_stage(umi_msg);\n"
        "\t\t}\n",
    ),
    (
        "\t\tif (error != EINVAL) {\n"
        "\t\t\tprintf(\"%s_mountroot failed: %d\\n\", vfsp->vfc_name, error);\n"
        "\t\t}\n"
        "\t}\n"
        "\tKDBG_RELEASE(DBG_MOUNTROOT | DBG_FUNC_END, error ? error : ENODEV, 4);\n"
        "\treturn ENODEV;\n",
        "\t\tif (error != EINVAL) {\n"
        "\t\t\tprintf(\"%s_mountroot failed: %d\\n\", vfsp->vfc_name, error);\n"
        "\t\t}\n"
        "\t\t{\n"
        "\t\t\tchar umi_msg[128];\n"
        "\n"
        "\t\t\t(void)snprintf(umi_msg, sizeof(umi_msg), \"MR %s=%d\", vfsp->vfc_name, error);\n"
        "\t\t\tboot_progress_stage(umi_msg);\n"
        "\t\t}\n"
        "\t}\n"
        "\tKDBG_RELEASE(DBG_MOUNTROOT | DBG_FUNC_END, error ? error : ENODEV, 4);\n"
        "\t{\n"
        "\t\tchar umi_msg[128];\n"
        "\n"
        "\t\t(void)snprintf(umi_msg, sizeof(umi_msg), \"MR exhausted last=%d\", error);\n"
        "\t\tboot_progress_stage(umi_msg);\n"
        "\t}\n"
        "\treturn ENODEV;\n",
    ),
])
PY
[ $? -eq 0 ] || { echo "EDIT-FAIL"; rm -rf "$WORK"; exit 1; }

echo
echo "== 2. 逐文件 diff =="
: > "$WORK/body.diff"
for rel in bsd/kern/bsd_init.c bsd/vfs/vfs_subr.c; do
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
grep -n "boot_progress_stage(umi_msg)" "$WORK/b/bsd/kern/bsd_init.c" "$WORK/b/bsd/vfs/vfs_subr.c"
rm -rf "$WORK"
echo done
