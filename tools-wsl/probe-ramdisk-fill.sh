#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/ramdisk-fill-and-amfi.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
U=/home/unixnu/code/UniXNU
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

say "== 1. DarwinBoot 填 RAMDisk 的完整判定（460-600 摘要）=="
grep -n 'Ramdisk\|RamdiskOffset\|KeepPacked\|Initrd\|LoadFile2\|Request' "$U/drivers/DarwinBoot/DarwinBootPkg/Driver/DarwinBoot.c" 2>/dev/null | head -40 >> "$OUT"

say
say "== 2. 内核里 AMFI / MAC 策略是否存在 =="
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho
source /usr/local/bin/unixnu-env 2>/dev/null
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
export PATH="$TC/CommandLineTools/usr/bin:$TC/bin:$PATH"
export XNU_TOOLCHAIN_BIN="$TC/CommandLineTools/usr/bin $TC/XcodeDefault.xctoolchain/usr/bin"
export UNIXNU_SDKROOT=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/fakeroot UNIXNU_SDK_VERSION=17.0
for s in AMFI amfi mac_vnode_check_exec cs_validate AppleMobileFileIntegrity code_signing; do
  say "$s -> $(xcrun nm "$K" 2>/dev/null | grep -ci "$s")"
done

say
say "== 3. umi_adt.py 的 at() 语义（节点不存在会怎样）=="
grep -n -A12 'def at' "$U/scripts/umi_adt.py" 2>/dev/null | head -30 >> "$OUT"

say
say "== 4. 基线 ADT 里有没有 /chosen/memory-map =="
python3 - "$U" <<'PY' >> "$OUT" 2>&1
import sys, importlib.util, pathlib
root = pathlib.Path(sys.argv[1])
for cand in (root/'scripts/umi_adt.py', root/'scripts/make-sheng-adt.py'):
    if cand.exists():
        spec = importlib.util.spec_from_file_location('adt', cand)
        m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
        break
else:
    print('no adt module'); raise SystemExit
import glob
files = sorted(glob.glob('/home/unixnu/code/umi-work-pin/out/umi*/**/kernel.macho.adt', recursive=True), key=lambda p: -pathlib.Path(p).stat().st_mtime)
print('adt candidates:', len(files))
for f in files[:3]:
    b = pathlib.Path(f).read_bytes()
    print(f, len(b), 'has memory-map:', b.count(b'memory-map'), 'RAMDisk:', b.count(b'RAMDisk'))
PY
say done
