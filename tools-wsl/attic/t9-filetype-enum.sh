#!/bin/bash
# T 步判据前置（四）：本树 filetype 枚举值（7 到底是不是 MH_DYLINKER）+ 签名字段实地核对
set -u
exec > /mnt/e/Code/HackIos/out/probes/t9-filetype-enum.txt 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
EL=/home/unixnu/code/umi-work-pin/out/umi-xnu/apple-el0

echo "== 1. EXTERNAL_HEADERS/mach-o/loader.h 的 filetype 段（90..135 行）=="
sed -n '88,135p' "$X/EXTERNAL_HEADERS/mach-o/loader.h"
echo "-- 全树 MH_DYLINKER 的定义处 --"
grep -rn 'MH_DYLINKER[[:space:]]*=' "$X" 2>/dev/null | grep -v Binary | head -5
grep -rn 'MH_DYLINKER' "$X/EXTERNAL_HEADERS/mach-o/loader.h" | head -5

echo
echo "== 2. 签名字段实地：superblob 头 + 第一张 CD 头 =="
python3 - "$EL" <<'PY'
import struct, sys, pathlib
el = pathlib.Path(sys.argv[1])
for name, sig_off in (('launchd', 536128), ('dyld', 911680)):
    d = (el / name).read_bytes()
    print(f'-- {name} @ {sig_off} --')
    print('  superblob:', ' '.join(f'{b:02x}' for b in d[sig_off:sig_off + 24]))
    m, ln, ver, cnt = struct.unpack_from('>4I', d, sig_off)
    print(f'  magic={m:#x} length={ln} version={ver} count={cnt}')
    for i in range(cnt):
        entry_off, entry_size = struct.unpack_from('>2I', d, sig_off + 16 + 8 * i)
        at = sig_off + entry_off
        cm, cl = struct.unpack_from('>2I', d, at)
        print(f'   slot[{i}] type={entry_size:#x} at={entry_off} magic={cm:#x} len={cl}')
        if cm in (0xfade0b01, 0xfade0c02):
            cdver, flags = struct.unpack_from('>2H', d, at + 8)
            print(f'      CD version={cdver:#x} flags={flags:#x}')
PY

echo
echo "== 3. 内核 create_proxy_mapping 里 depth 的语义（dyld 是不是 depth 2）=="
grep -n -B4 -A12 'depth != 2\|depth == 2\|int depth' "$X/bsd/kern/mach_loader.c" | head -60
echo "== done $(date -u +%FT%TZ)"
