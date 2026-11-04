#!/bin/bash
# U 步之二之三：storage providers（原版 IOAESAccelerator 派发 + 签名策略 NativeVirtioBlock）
# 静态段不需要 QEMU；活体段要一份停在 _bsd_init 的快照，读三个元类（AES 元类、IOService 元类、
# 以及从 AES 元类 +16 处取到的父元类链）。SCTLR_EL1 由 make-gdb-stop-sctlr-observer.py 的别名观测件补。
# 用法：run-storage-providers.sh static
#       run-storage-providers.sh live [run 名基，默认 run-50] [复用 ESP 的档] [已含 AES 元类读址的快照档]
# 第三参给了就跳过第一档：父元类从那份快照的 AES 元类 +16 处取，只再启动一次 QEMU。
set -u
MODE=${1:-static}
BASE=${2:-run-50}
ESP_FROM=${3:-}
META_FROM=${4:-}
PIN=/home/unixnu/code/umi-work-pin
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
KDIR=$PIN/out/umi-xnu/umi/kernel
CAND=$KDIR/qemu-native-ufs-trace.macho
SRC_K=$KDIR/apfs-prelink-kernel.macho
OUT=$PIN/out/umi-xnu/umi/tree/build/umi-storage-providers
ARGS="-v keepsyms=1 kt_fixed_zones=120 offline-apfs-load=1"

if [ "$MODE" = static ]; then
  exec > /mnt/e/Code/HackIos/out/probes/storage-providers-static.txt 2>&1
else
  exec > /mnt/e/Code/HackIos/out/probes/storage-providers-live.txt 2>&1
fi

source /usr/local/bin/unixnu-env 2>/dev/null
export PATH="$TC/CommandLineTools/usr/bin:$TC/bin:/usr/local/bin:/usr/bin:/bin"
export LC_ALL=C CLT_PREFIX=$TC/CommandLineTools/usr XCTOOLCHAIN_PREFIX=$TC/XcodeDefault.xctoolchain/usr
export XNU_TOOLCHAIN_BIN="$TC/CommandLineTools/usr/bin $TC/XcodeDefault.xctoolchain/usr/bin"
export UNIXNU_SDKROOT=$PIN/out/umi-xnu/umi/tree/.cache/fakeroot UNIXNU_SDK_VERSION=17.0
export UNIXNU_PLATFORM_PATH=$PIN/out/umi-xnu/umi/tree/.cache/fakeroot/Platforms/iPhoneOS.platform
export CCC_OVERRIDE_OPTIONS='# +-Wno-missing-designated-field-initializers +-Wno-unused-but-set-global +-Wno-unnecessary-virtual-specifier +-Wno-deprecated-enum-enum-conversion'
cd $PIN || exit 1

# providers 把候选内核写死成 out/umi-xnu/umi/kernel/qemu-native-ufs-trace.macho（+ 同名 .json），
# 那是官方链路上「上一轮全存储 prelink 候选」的名字——按 build_umi_xnu.py 的顺序，providers 跑在
# kernel 步之前，吃的必然是既有候选。本仓这一件叫 apfs-prelink-kernel.macho，所以这里用符号链接
# 把同一份字节挂到工具期望的名字上（不造第二份内核，也让 provenance 一眼看出指向）。
echo "== 0. 候选落名：qemu-native-ufs-trace -> apfs-prelink-kernel =="
python3 - <<'PYEOF'
import hashlib, json, pathlib
k = pathlib.Path('/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel')
src, plan = k/'apfs-prelink-kernel.macho', k/'apfs-prelink-kernel.json'
if not (src.exists() and plan.exists()):
    raise SystemExit('缺 apfs-prelink-kernel.macho/.json —— 先跑 run-umi-prelink.sh')
d = json.loads(plan.read_text())
digest = hashlib.sha256(src.read_bytes()).hexdigest()
print('  apfs-prelink-kernel.macho sha =', digest)
print('  plan candidate_sha256          =', d['candidate_sha256'], '一致' if d['candidate_sha256'] == digest else '不一致')
print('  plan original_sha256           =', d['original_sha256'])
print('  工具里钉的原版                 = f18b4df865405f2a287b84977d7aca745e056d656d9fc9df1662970ce2969de7',
      '一致' if d['original_sha256'] == 'f18b4df865405f2a287b84977d7aca745e056d656d9fc9df1662970ce2969de7' else '不一致')
if d['candidate_sha256'] != digest:
    raise SystemExit('候选与 plan 记录已分叉，别绑')
for ext, target in ((k/'qemu-native-ufs-trace.macho', src), (k/'qemu-native-ufs-trace.json', plan)):
    if ext.is_symlink() and ext.resolve() == target.resolve():
        print(f'  {ext.name} 已指向源件'); continue
    if ext.exists():
        print(f'  {ext.name} 已存在且不是指向源件的链接 —— 停手，人工判'); raise SystemExit(1)
    ext.symlink_to(target.name)
    print(f'  已建链接 {ext.name} -> {target.name}')
PYEOF

if [ "$MODE" = static ]; then
  echo
  echo "== 1. providers 静态段（不带 --snapshot）=="
  time python3 -u tools/build_umi_storage_providers.py 2>&1 | tail -30
  echo "退出码=${PIPESTATUS[0]}"
  echo
  echo "== 2. aes-static.json 关键地址 =="
  python3 - <<'PYEOF'
import json, pathlib
p = pathlib.Path('/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/umi-storage-providers/aes-static.json')
if not p.exists():
    print('  还没产出'); raise SystemExit(0)
d = json.loads(p.read_text())
for k in ('candidate_sha256','original_sha256','vtable','aes_metaclass','service_metaclass',
          'method_slots','inherited_kernel_matches','annotation_source','annotation_sha256'):
    print(f'  {k:>24} = {d.get(k)}')
print('  methods 条数 =', len(d.get('methods', [])))
print('  下一个命令：run-storage-providers.sh live <基名>   # 会读上面两个元类地址')
PYEOF
  echo "done $(date -u +%FT%TZ)"
  exit 0
fi

S1=$PIN/out/umi-qemu/$BASE-aes-live
S2=$PIN/out/umi-qemu/${BASE}b-aes-live-abi
mkdir -p $S2
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/make-gdb-stop-sctlr-observer.py > /tmp/make-observer.py

echo
echo "== 1. 取静态段算出的两个元类地址 =="
python3 - <<'PYEOF' > /tmp/aes-addr.env
import json
d = json.loads(open('/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/umi-storage-providers/aes-static.json').read())
print('AES_META=%s' % int(d['aes_metaclass'], 16))
print('IO_SERVICE_META=%s' % int(d['service_metaclass'], 16))
PYEOF
source /tmp/aes-addr.env
printf '  AES 元类      = 0x%016x\n  IOService 元类= 0x%016x\n' "$AES_META" "$IO_SERVICE_META"

meta_at() {  # 从某档快照里取 AES 元类 +16 的 superClassLink（父元类）
  python3 - "$1" "$AES_META" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1] + '/gdb-stop.json'))
target = int(sys.argv[2])
meta = None
for k, v in d['memory'].items():
    if int(k.split(':')[0], 16) == target:
        meta = bytes.fromhex(v)
        break
if meta is None or len(meta) < 24:
    print('0 %s %s' % (d['pc'], d['bounded_timeout_interrupted']))
else:
    print('%d %s %s' % (int.from_bytes(meta[16:24], 'little'), d['pc'], d['bounded_timeout_interrupted']))
PYEOF
}

if [ -n "$META_FROM" ]; then
  echo
  echo "== 2. 父元类取自既有快照（跳过第一档）：$META_FROM =="
  read -r AES_PARENT_META STOP_PC STOP_TIMEOUT <<<"$(meta_at "$META_FROM")"
  printf '  来源档 pc = %s  timed_out = %s\n  父元类 = 0x%016x\n' "$STOP_PC" "$STOP_TIMEOUT" "$AES_PARENT_META"
else
  echo
  echo "== 2. 第一档：停 _bsd_init，读这两个元类（产 ESP + 父元类地址）=="
  tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/run-umi-qemu.sh > /tmp/run-umi-qemu.sh
  KERNEL=$CAND bash /tmp/run-umi-qemu.sh $BASE-aes-live \
    --stop _bsd_init --args "$ARGS" --timeout 600 --capture-screen \
    --read-address $(printf '%x:50' "$AES_META") --read-address $(printf '%x:50' "$IO_SERVICE_META")
  S1=$PIN/out/umi-qemu/$BASE-aes-live
  read -r AES_PARENT_META STOP_PC STOP_TIMEOUT <<<"$(meta_at "$S1")"
  printf '  本档 pc = %s  timed_out = %s\n  父元类 = 0x%016x\n' "$STOP_PC" "$STOP_TIMEOUT" "$AES_PARENT_META"
fi

if [ "$STOP_TIMEOUT" != "False" ] || [ "$AES_PARENT_META" = "0" ]; then
  echo "  停手：父元类取不到（超时会停在 IOKit 之前的任意点，元类还没成型）。"
  echo "  先确认这份快照确实停在 _bsd_init（pc 与 nm 的 _bsd_init 相等、timed_out=False），再重跑。"
  echo "done $(date -u +%FT%TZ)"; exit 1
fi
[ -d "$S1/esp" ] || S1=${ESP_FROM:-$S1}
[ -f "$S1/provenance.json" ] || { echo "  缺 $S1/provenance.json，无法复用 ESP"; echo "done $(date -u +%FT%TZ)"; exit 1; }
printf '  ESP 复用自：%s\n' "$S1"

echo
echo "== 3. 别名观测件启动一次：补 SCTLR_EL1，读三个元类 =="
python3 /tmp/make-observer.py --output $S2/gdb-stop-sctlr.py || exit 1
python3 - <<PYEOF
import json, subprocess
command = list(json.loads(open('$S1/provenance.json').read())['command'])
command[1] = '$S2/gdb-stop-sctlr.py'
for i, item in enumerate(command):
    if item == '--fixture':
        command[i + 1] = '$S2'
    if item == '--timeout':
        command[i + 1] = '600'
while '--read-memory' in command:
    i = command.index('--read-memory'); del command[i:i + 2]
for address in ('$AES_META', '$IO_SERVICE_META', '$AES_PARENT_META'):
    command += ['--read-memory', '%x:50' % int(address)]
print('  读址:', [c for c in command if c.endswith(':50')])
log = open('$S2/observer.log', 'w')
print('  观测件退出码 =', subprocess.run(command, stdout=log, stderr=subprocess.STDOUT).returncode)
log.close()
PYEOF

echo
echo "== 4. 快照判定 =="
python3 - <<PYEOF
import json
d = json.load(open('$S2/gdb-stop.json'))
print('  pc =', d['pc'], ' kernel_sha256 =', d['kernel_sha256'])
print('  bounded_timeout_interrupted =', d['bounded_timeout_interrupted'])
r = d['system_registers']
for k in ('SCTLR_EL1', 'TCR_EL1', 'TTBR0_EL1', 'TTBR1_EL1'):
    if k in r:
        print(f'    {k:>10} = {r[k]}')
print('  memory 键 =', sorted(d['memory']))
for k, v in sorted(d['memory'].items()):
    print(f'    {k} -> {len(v) // 2} 字节')
PYEOF

echo
echo "== 5. providers 活体段 + 绑定（出 aes-interface-audit.json / libNativeAES.a / libNativeVirtioBlock.a）=="
time python3 -u tools/build_umi_storage_providers.py --snapshot $S2/gdb-stop.json 2>&1 | tail -40
echo "退出码=${PIPESTATUS[0]}"
echo "-- 产物 --"
ls -la $OUT 2>&1 | head -30
[ -f $OUT/build-report.json ] && python3 -c "
import json;d=json.loads(open('$OUT/build-report.json').read())
for k in ('aes_archive_sha256','virtio_archive_sha256','aes_runtime_tested','root_binding_runtime_tested'):
    print('  ',k,'=',d.get(k))
print('   aes_bindings.bindings 条数 =',len(d.get('aes_bindings',{}).get('bindings',{})))
print('   virtio_bindings.bindings 条数 =',len(d.get('virtio_bindings',{}).get('bindings',{})))
"
echo "done $(date -u +%FT%TZ)"
