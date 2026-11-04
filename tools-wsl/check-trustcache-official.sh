#!/usr/bin/env bash
# 跑上游官方 check_umi_trustcache_qemu.py（不改它一个字），并取回屏照。
# 前提：/usr/bin/xcrun 是 Linux shim，nm 只在工具链进 PATH 后可用，否则退化成 GNU nm
#       对 Mach-O 报 file format not recognized。
set -u
exec > /mnt/e/Code/HackIos/out/probes/check-trustcache-official.log 2>&1
WS=/home/unixnu/code/umi-work-pin
TC=${XNU_TOOLCHAIN_BIN:-/opt/unixnu-linux/CommandLineTools/usr/bin}
export XNU_TOOLCHAIN_BIN="$TC:/opt/unixnu-linux/CommandLineTools/usr/bin:/opt/unixnu-linux/bin"
export PATH="/opt/unixnu-linux/CommandLineTools/usr/bin:/opt/unixnu-linux/bin:/usr/local/bin:/usr/bin:/bin"
cd "$WS" || exit 2
echo "== xcrun nm 自检 =="
command -v xcrun; xcrun nm -n out/umi-xnu/umi/kernel/qemu-trustcache-runtime.macho 2>&1 | wc -l
echo "== 官方 check 件 =="
python3 tools/check_umi_trustcache_qemu.py; echo "official check exit=$?"
echo "== 产出的 baseline =="
python3 -c "import json;print(json.dumps(json.load(open('out/umi/trustcache-qemu-baseline.json')),indent=2,ensure_ascii=False))" 2>&1 | head -60
cp -f out/umi-qemu/38-trustcache-query/screen.png /mnt/e/Code/HackIos/out/screens/39-trustcache-query.png 2>&1
ls -l /mnt/e/Code/HackIos/out/screens/39-trustcache-query.png
