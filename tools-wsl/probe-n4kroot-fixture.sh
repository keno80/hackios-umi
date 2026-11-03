#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/n4kroot-fixture.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
S=/home/unixnu/code/UniXNU-main
R=/home/unixnu/code/UniXNU-umi
LOGD=$S/out/unixnu-logs

say "== 0. 内核构建进度 =="
L=$(cat "$LOGD/kernel-mockfs-latest.txt"); say "log=$L"
tail -6 "$L" 2>&1 >> "$OUT"
say "-- 进程还在吗 --"
pgrep -f 'build_umi_xnu.py' >/dev/null && say RUNNING || say DONE_OR_DEAD

say
say "== 1. build-native-user-fixture.py 的文档与入参 =="
sed -n '1,50p' "$S/scripts/build-native-user-fixture.py" >> "$OUT" 2>&1
say "-- 是否依赖 mac 工具 --"
grep -n 'hdiutil\|diskutil\|codesign\|xcrun\|ld \|clang\|sys.argv\|add_argument' "$S/scripts/build-native-user-fixture.py" | head -25 >> "$OUT"

say
say "== 2. N4KROOT 头的写入处 =="
grep -n -B4 -A18 'N4KROOT' "$S/scripts/build-native-user-fixture.py" | head -60 >> "$OUT"

say
say "== 3. 谁调用这个 fixture（板子/步骤）=="
grep -rn 'build-native-user-fixture\|native-user-fixture\|user_fixture' "$S/scripts" "$R" 2>/dev/null | grep -v Binary | head -20 >> "$OUT"

say
say "== 4. build-target-dyld-fixture.py 的入参 =="
grep -n 'add_argument\|^\"\"\"\|^"""' "$S/scripts/build-target-dyld-fixture.py" | head -20 >> "$OUT"
sed -n '1,24p' "$S/scripts/build-target-dyld-fixture.py" >> "$OUT" 2>&1
say done
