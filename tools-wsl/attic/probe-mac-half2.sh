#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/mac-half2.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
S=/home/unixnu/code/UniXNU-main
W=/home/unixnu/code/umi-work-pin

say "== 1. packed_ramdisk 是否纯 Python（造 seed 的打包步）=="
F=$(find "$S/drivers/DarwinBoot/Test" -maxdepth 1 -name 'packed_ramdisk.py' 2>/dev/null | head -1)
say "F=$F"
test -n "$F" && { wc -l "$F" >> "$OUT"; grep -n 'import \|hdiutil\|diskutil\|subprocess\|def pack\|struct\|zlib\|lzfse' "$F" | head -25 >> "$OUT"; }

say
say "== 2. 所有仍依赖 hdiutil/diskutil 的脚本 =="
grep -rln "hdiutil\|diskutil" "$S/scripts" 2>/dev/null >> "$OUT"

say
say "== 3. NXSB 断言在哪（seed 必须是 packed APFS 的出处）=="
grep -rn 'NXSB' "$W/tools" "$S/scripts" 2>/dev/null | head -15 >> "$OUT"
say "-- umi 侧 --data-ramdisk 读 identity json --"
grep -rn 'identity\|volume_uuid' "$W/tools/build_umi_xnu.py" 2>/dev/null | head -15 >> "$OUT"

say
say "== 4. seed-data-skip-setup.py / prepare-owner-data-fixture 的 mac 依赖行 =="
grep -n 'hdiutil\|diskutil\|apfs' "$S/scripts/seed-data-skip-setup.py" "$S/scripts/prepare-owner-data-fixture.py" 2>/dev/null | head -25 >> "$OUT"

say
say "== 5. mkapfs 能力实测：能不能造出能被内核读的 APFS =="
mkapfs 2>&1 | head -20 >> "$OUT"
say "-- 版本 --"
dpkg -s apfsprogs 2>/dev/null | grep -E 'Version|Depends' >> "$OUT"
say "-- apfs-dkms 能否配 WSL 内核头 --"
ls /lib/modules/ 2>/dev/null >> "$OUT"
apt-cache policy apfs-dkms 2>&1 | head -6 >> "$OUT"

say
say "== 6. macOS 侧还差的 TargetConditionals.h 有没有现成源 =="
find / -maxdepth 7 -name 'TargetConditionals.h' 2>/dev/null | head -8 >> "$OUT"
say "-- 树内 xnu 有没有带 --"
grep -rl 'TargetConditionals' "$S" 2>/dev/null | head -8 >> "$OUT"
say done
