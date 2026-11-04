#!/bin/bash
# storage ABI 活体段：停在 _bsd_init，读两个元类 0x50 字节 + 带 SCTLR_EL1 别名的系统寄存器，
# 再把快照喂给 audit_umi_storage.py 出 interface-audit.json。
# 用法：run-storage-abi-snapshot.sh [run 名基，默认 run-47] [复用 ESP 的既有档，可省]
exec > /mnt/e/Code/HackIos/out/probes/storage-abi-live-snapshot.txt 2>&1
set -u

BASE=${1:-run-47}
ESP_FROM=${2:-}
PIN=/home/unixnu/code/umi-work-pin
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
CAND=$PIN/out/umi-xnu/umi/kernel/apfs-prelink-kernel.macho
STABI=$PIN/out/umi/storage-abi
S1=$PIN/out/umi-qemu/$BASE-bsdinit
S2=$PIN/out/umi-qemu/${BASE}b-bsdinit-abi
ARGS="-v keepsyms=1 kt_fixed_zones=120 offline-apfs-load=1"

source /usr/local/bin/unixnu-env 2>/dev/null
export PATH="$TC/CommandLineTools/usr/bin:$TC/bin:/usr/local/bin:/usr/bin:/bin"
export LC_ALL=C CLT_PREFIX=$TC/CommandLineTools/usr XCTOOLCHAIN_PREFIX=$TC/XcodeDefault.xctoolchain/usr
export XNU_TOOLCHAIN_BIN="$TC/CommandLineTools/usr/bin $TC/XcodeDefault.xctoolchain/usr/bin"
export UNIXNU_SDKROOT=$PIN/out/umi-xnu/umi/tree/.cache/fakeroot UNIXNU_SDK_VERSION=17.0
export UNIXNU_PLATFORM_PATH=$PIN/out/umi-xnu/umi/tree/.cache/fakeroot/Platforms/iPhoneOS.platform
export CCC_OVERRIDE_OPTIONS='# +-Wno-missing-designated-field-initializers +-Wno-unused-but-set-global +-Wno-unnecessary-virtual-specifier +-Wno-deprecated-enum-enum-conversion'

echo "== 0. 锚点唯一性预检 =="
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/make-gdb-stop-sctlr-observer.py > /tmp/make-observer.py
python3 - <<'PYEOF'
src = open('/home/unixnu/code/UniXNU-pin/scripts/qemu-entry/gdb-stop.py').read()
for name, needle in (('alias-def', "                report['system_registers'] = {}\n"),
                     ('wanted', "                wanted = {'TCR_EL1'"),
                     ('store', "                            report['system_registers'][register.attrib['name']] = hex(value)\n"),
                     ('import', "\nimport argparse\n")):
    print(f'  {name}: {src.count(needle)} 次')
PYEOF

echo
echo "== 1. 候选内核 sha =="
sha256sum $CAND

echo
echo "== 2. 第一档：run_umi_qemu 停 _bsd_init（产 ESP + 两个元类读址）=="
cd $PIN || exit 1
if [ -n "$ESP_FROM" ]; then
  S1=$ESP_FROM
  echo "  复用已备好的 ESP 档：$S1（跳过第一档启动）"
  [ -f "$S1/provenance.json" ] || { echo "  该档没有 provenance.json，没法复用"; exit 1; }
else
  tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/run-umi-qemu.sh > /tmp/run-umi-qemu.sh
  KERNEL=$CAND bash /tmp/run-umi-qemu.sh $BASE-bsdinit \
    --stop _bsd_init --args "$ARGS" --timeout 300 --capture-screen \
    --read-address fffffff006add1d0:50 --read-address fffffff007b00eb8:50
fi
echo "第一档目录："
ls -la $S1 2>&1 | head -12

echo
echo "== 3. 产别名观测件 =="
mkdir -p $S2
python3 /tmp/make-observer.py --output $S2/gdb-stop-sctlr.py || exit 1
grep -n "QEMU_SCTLR_EL1_ALIAS" $S2/gdb-stop-sctlr.py | head -5

echo
echo "== 4. 第二档：同 ESP 换观测件重跑，采带 SCTLR_EL1 的快照 =="
python3 - <<PYEOF
import json, subprocess, os, sys
raw = open('$S1/provenance.json').read()
if 'command' not in raw:
    print('  第一档没出 provenance，后面没法复用 —— 看上面 run_umi_qemu 的报错'); sys.exit(1)
prov = json.loads(raw)
command = list(prov['command'])
command[1] = '$S2/gdb-stop-sctlr.py'
for i, item in enumerate(command):
    if item == '--fixture':
        command[i + 1] = '$S2'
print('  新命令:', ' '.join(command)[:400])
log = open('$S2/observer.log', 'w')
rc = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT).returncode
log.close()
print('  观测件退出码 =', rc)
PYEOF
echo "-- run-47b 目录 --"
ls -la $S2 2>&1 | head -12

echo
echo "== 5. 快照判定 =="
python3 - <<PYEOF
import json
d = json.load(open('$S2/gdb-stop.json'))
r = {k: int(v, 16) for k, v in d['system_registers'].items()}
print('  pc =', d['pc'], '  bounded_timeout_interrupted =', d['bounded_timeout_interrupted'])
print('  kernel_sha256 =', d['kernel_sha256'])
print('  寄存器键 =', sorted(d['system_registers']))
for k in ('SCTLR_EL1', 'SCTLR', 'ATCR_EL1', 'TCR_EL1', 'TTBR0_EL1', 'TTBR1_EL1'):
    if k in d['system_registers']:
        v = r[k]
        extra = ''
        if k.startswith('SCTLR'):
            extra = f"  M(bit0)={v & 1} C(bit1)={v >> 1 & 1} A(bit2)={v >> 2 & 1} I(bit12)={v >> 12 & 1} SA(bit15)={v >> 15 & 1}"
        print(f'    {k:>10} = {d["system_registers"][k]}{extra}')
print('  memory 键 =', sorted(d['memory']))
for k, v in d['memory'].items():
    print(f'    {k} -> {len(v) // 2} 字节')
PYEOF

echo
echo "== 6. 活体审计出 interface-audit.json =="
cd $PIN || exit 1
time python3 tools/audit_umi_storage.py --candidate $CAND --snapshot $S2/gdb-stop.json 2>&1 | tail -30
echo "审计退出码=${PIPESTATUS[0]}"
echo "-- 产物 --"
ls -la $STABI/ 2>&1
[ -f $STABI/interface-audit.json ] && cat $STABI/interface-audit.json

echo "done $(date -u +%FT%TZ)"
