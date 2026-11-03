#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/mockfs-verify.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
S=/home/unixnu/code/UniXNU-main
W=/home/unixnu/code/umi-work-pin
TREE=$W/out/umi-xnu/umi/tree
X=$TREE/.cache/xnu-work
source /usr/local/bin/unixnu-env 2>/dev/null
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
export XNU_TOOLCHAIN_BIN="$TC/CommandLineTools/usr/bin $TC/XcodeDefault.xctoolchain/usr/bin"
export PATH="$TC/CommandLineTools/usr/bin:$TC/bin:$PATH"
export UNIXNU_SDKROOT=$TREE/.cache/fakeroot UNIXNU_SDK_VERSION=17.0

say "== 1. 新内核里的 mockfs 符号 =="
K=$(ls -t $W/out/umi-xnu/umi/kernel/*.macho 2>/dev/null | head -1)
say "K=$K  sha=$(sha256sum "$K" 2>/dev/null | cut -c1-16)"
say "mockfs 符号数 -> $(xcrun nm "$K" 2>/dev/null | grep -c mockfs)"
xcrun nm "$K" 2>/dev/null | grep -E 'mockfs_mountroot|mockfs_vfsops|_mockfs_root$' | head -6 >> "$OUT"
say "-- 挂载候选表里的类型号 --"
xcrun nm "$K" 2>/dev/null | grep -cE 'vfs_mountroot|vfs_conf' >> "$OUT"

say
say "== 2. 构建报告里的 kernfs/mock 记录 =="
grep -n 'MOCKFS\|mockfs' "$W/out/umi-xnu/umi/build-report.json" 2>/dev/null | head -10 >> "$OUT"
tail -4 "$TREE"/build/mockfs-fixture/*.log 2>/dev/null | head -8 >> "$OUT"

say
say "== 3. mockfs 的文件名映射（根/dev/可执行文件叫什么）=="
grep -n 'MOCKFS_ROOT\|MOCKFS_DEV\|MOCKFS_FILE\|MOCKFS_TEST_FILE\|"' "$X/bsd/miscfs/mockfs/mockfs_fsnode.h" | head -20 >> "$OUT"
say "-- vfsops 里的名字表 --"
grep -n -B3 -A12 'mockfs_name\|MOCKFS_DEV\|static const char' "$X/bsd/miscfs/mockfs/mockfs_vfsops.c" | head -40 >> "$OUT"

say
say "== 4. bsd_init 挂上假根后 exec 的是什么 =="
grep -n 'launchd\|INIT_PATH\|exec_init_process\|load_unixexec\|cpaywt\|rdh' "$X/bsd/kern/bsd_init.c" | head -25 >> "$OUT"

say
say "== 5. umi 打包里的 RAMDisk 占位机制 =="
sed -n '100,160p' "$W/tools/make_umi_payload.py" >> "$OUT" 2>&1
say "-- run_umi_qemu 的对应段 --"
sed -n '200,222p' "$W/tools/run_umi_qemu.py" >> "$OUT" 2>&1
say done
