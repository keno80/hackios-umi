#!/bin/bash
# T 步判据前置：真件的 load command 清单 + 内核按什么认 dyld（filetype 7 是不是闸）
set -u
exec > /mnt/e/Code/HackIos/out/probes/t6-loadcmds.txt 2>&1
EL=/home/unixnu/code/umi-work-pin/out/umi-xnu/apple-el0
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

python3 - "$EL" <<'PY'
import struct, sys, pathlib
NAMES = {0x1:'LC_SEGMENT',0x2:'LC_SYMTAB',0xb:'LC_DYSYMTAB',0xc:'LC_LOAD_DYLIB',0xd:'LC_ID_DYLIB',
         0xf:'LC_LOAD_DYLINKER',0x10:'LC_ID_DYLINKER',0x11:'LC_PREBOUND_DYLIB',0x19:'LC_SEGMENT_64',
         0x1a:'LC_ROUTINES_64',0x1b:'LC_UUID',0x1d:'LC_CODE_SIGNATURE',0x1e:'LC_SEGMENT_SPLIT_INFO',
         0x21:'LC_ENCRYPTION_INFO',0x22:'LC_DYLD_INFO',0x24:'LC_DYLD_INFO_ONLY',0x25:'LC_LOAD_UPWARD_DYLIB',
         0x26:'LC_FUNCTION_STARTS',0x27:'LC_DYLD_ENVIRONMENT',0x28:'LC_MAIN',0x29:'LC_DATA_IN_CODE',
         0x2a:'LC_FUNCTION_VANISHING',0x2b:'LC_SOURCE_LOCATIONS',0x80000018:'LC_LOAD_WEAK_DYLIB',
         0x8000001c:'LC_RPATH',0x8000001f:'LC_REEXPORT_DYLIB',0x80000022:'LC_DYLD_INFO_ONLY',
         0x80000027:'LC_VERSION_MIN_IPHONEOS',0x80000032:'LC_BUILD_VERSION'}
el = pathlib.Path(sys.argv[1])
for n in ('launchd', 'dyld'):
    d = (el / n).read_bytes()
    magic, cputype, cpusub, filetype, ncmds, sizecmds, flags, resv = struct.unpack_from('<8I', d)
    print(f'== {n} == filetype={filetype} ncmds={ncmds} sizeofcmds={sizecmds} flags={flags:#x}')
    at = 32
    for i in range(ncmds):
        cmd, length = struct.unpack_from('<II', d, at)
        extra = ''
        if cmd in (0xf, 0x10, 0x80000025):
            o = struct.unpack_from('<I', d, at + 8)[0]
            extra = d[at + o:d.index(b'\0', at + o)].decode(errors='replace')
        elif cmd == 0xc or cmd == 0xd or cmd == 0x80000018 or cmd == 0x8000001f:
            o = struct.unpack_from('<I', d, at + 8)[0]
            extra = d[at + o:d.index(b'\0', at + o)].decode(errors='replace')
        elif cmd == 0x28:
            ep, stack = struct.unpack_from('<QQ', d, at + 8)
            extra = f'entryoff={ep:#x} stack={stack}'
        elif cmd == 0x1d or cmd == 0x26 or cmd == 0x1e or cmd == 0x29:
            extra = 'off=%d size=%d' % struct.unpack_from('<II', d, at + 8)
        elif cmd == 0x32 or cmd == 0x80000027:
            extra = 'min=' + ','.join(str(v) for v in struct.unpack_from('<3I', d, at + 8))
        print(f'  [{i:2}] {cmd:#010x} {NAMES.get(cmd, "?"):24} size={length:5} {extra}')
        at += length
    print()
PY

echo "== 内核侧：exec 时怎么挑 dyld、按什么校验 filetype =="
grep -rn 'MH_DYLINKER' "$X/bsd/kern/"*.c "$X/mach-o/loader.h" 2>/dev/null | head -20
echo "-- macho_loader 里的 dylinker 装载段 --"
grep -rn -B6 -A24 'load_dylinker' "$X/bsd/kern/macho_loader.c" 2>/dev/null | sed -n '1,80p'
echo
echo "-- 我们 AMFI 桩补丁给了什么答案（会不会放行 Apple 签名件）--"
grep -n 'amfi\|Amfi\|cs_\|cdhash\|trustcache' /mnt/e/Code/HackIos/patches/umi-xnu/*amfi-guard.patch | head -40
echo "== done $(date -u +%FT%TZ)"
