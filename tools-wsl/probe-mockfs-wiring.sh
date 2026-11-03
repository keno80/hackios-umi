#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/mockfs-wiring.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

say "== 1. mockfs 在整个 xnu 树里的注册点 =="
grep -rn 'mockfs' "$X/bsd/kern" "$X/bsd/miscfs/Makefile" "$X/bsd/conf" 2>/dev/null | grep -v '^Binary' | head -30 >> "$OUT"

say
say "== 2. mockfs_mountroot 的调用者与条件 =="
grep -rn 'mockfs_mountroot\|MOCKFS' "$X/bsd" --include=*.c --include=*.h 2>/dev/null | grep -vE 'miscfs/mockfs/' | head -30 >> "$OUT"

say
say "== 3. mockfs.h 的入参（需要哪些 boot arg / 设备）=="
sed -n '1,80p' "$X/bsd/miscfs/mockfs/mockfs.h" >> "$OUT" 2>&1

say
say "== 4. memdev 的 CONFIG_MEMDEV_INSECURE 有哪些配置能开 =="
grep -rn 'MEMDEV_INSECURE' "$X" 2>/dev/null | head -10 >> "$OUT"
say "-- 我们当前 .config 里的值 --"
grep -rn 'MEMDEV' /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/*.h 2>/dev/null | head -5 >> "$OUT"
find /home/unixnu/code/umi-work-pin/out/umi-xnu/umi -maxdepth 4 -name '.config' 2>/dev/null | head -3 >> "$OUT"

say
say "== 5. 两份 build_umi_xnu.py 的 git 身份 =="
cd /home/unixnu/code/umi-work-pin 2>/dev/null && { say "umi-work-pin branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) head=$(git rev-parse --short HEAD 2>/dev/null)"; git status --porcelain tools/build_umi_xnu.py 2>&1 | head -3 >> "$OUT"; }
cd /home/unixnu/code/UniXNU-umi 2>/dev/null && { say "UniXNU-umi branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) head=$(git rev-parse --short HEAD 2>/dev/null)"; }
say "-- diff 摘要 --"
diff /home/unixnu/code/umi-work-pin/tools/build_umi_xnu.py /home/unixnu/code/UniXNU-umi/bringup/tools/build_umi_xnu.py 2>&1 | head -20 >> "$OUT"
say done
