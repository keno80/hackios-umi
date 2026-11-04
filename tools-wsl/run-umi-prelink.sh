#!/bin/bash
# U 步之一之三：给 prelink 输入档内核注入 Apple 的 apfs + Zlib 压缩根
# 用法：run-umi-prelink <输出名，不含 .macho>
set -u
NAME=${1:-apfs-prelink-kernel}
WS=/home/unixnu/code/umi-work-pin
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
export PATH="$TC/CommandLineTools/usr/bin:$TC/bin:/usr/local/bin:/usr/bin:/bin"
export LC_ALL=C
cd "$WS" || exit 1
OUT=out/umi-xnu/umi/kernel/$NAME.macho
if [ -e "$OUT" ]; then echo "$OUT 已存在（build_umi_prelink 拒绝覆盖），换个名字"; exit 1; fi
LOG=/home/unixnu/code/UniXNU-main/out/unixnu-logs/prelink-$NAME-$(date +%H%M%S).log
echo "== 输入 $(sha256sum out/umi-xnu/umi/kernel/qemu-prelink-source-kernel.macho | cut -c1-16) -> $OUT"
python3 -u tools/build_umi_prelink.py --profile qemu --storage --output "$OUT" > "$LOG" 2>&1
echo "build_umi_prelink exit=$?"
tail -20 "$LOG"
echo "-- 产物与旁生件 --"
ls -l out/umi-xnu/umi/kernel/$NAME.macho* 2>/dev/null
[ -f "out/umi-xnu/umi/kernel/$NAME.json" ] && python3 - <<EOF
import json
d=json.load(open('out/umi-xnu/umi/kernel/$NAME.json'))
print('keys=',sorted(d))
print('components=',d.get('images_modified'), 'count=', len(d.get('components',[])))
for k in ('native_sha256','original_sha256','slide','loadable','abi_qualified','instruction_relocation_complete'):
    print(k,'=',d.get(k))
EOF
[ -f "out/umi-xnu/umi/kernel/$NAME.provenance.json" ] && python3 - <<EOF
import json
d=json.load(open('out/umi-xnu/umi/kernel/$NAME.provenance.json'))
for k in ('kernel_sha256','donor_sha256','component_count','virtual_span_bytes','owned_memory_bytes',
          'fat_volume_bytes','storage_prelink','requested_roots','runtime_qualified','hardware_tested'):
    print(k,'=',d.get(k))
EOF
