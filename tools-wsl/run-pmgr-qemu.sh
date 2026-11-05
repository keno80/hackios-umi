#!/bin/bash
# U 步之六之二：--pmgr 档在 QEMU 里的官方资格化取证
# 用法：run-pmgr-qemu.sh <off|lifecycle|publish|refusal|root|amfi|deep> [run名]
#   前置：run-kernel-systemos-pmgr.sh 编完 + run-umi-prelink.sh qemu-systemos-pmgr
#   判读：官方 tools/check_umi_pmgr_observation.py --mode <同名>（deep 不是官方档，只出我们自己的归因读数）
# 各档停点为什么这么挑（官方件里 stop 符号是写死的：off/refusal→_panic，root→_IOFindBSDRoot，
#   lifecycle/publish/amfi→_umi_pmgr_checkpoint）：
#   off     不给 umi-pmgr 旗标，复现原版 AMFI 在异步 thread call 里拿不到 nub 的 panic，
#           官方断言 x0 里有 "AMFI: No PMGR?" 且 16 个观测字全 0（证明仪表默认关、没偷偷改状态）
#   publish umi-pmgr=2，停在仪表自己的成功收口 checkpoint（stage=5、attached=1、registered=2、
#           own/nub 实例计数各 +1）——这是「原版 ApplePMGR/ApplePMGRNub 真身被发布」的正面证据
#   refusal umi-pmgr=3，停 _panic，断言 stage=0x100+170、status=0xe00002c7（不支持的下电请求真被拒）
#   root    umi-pmgr=2，停 _IOFindBSDRoot：看挂根边界到的时候发布态还在不在（有竞态风险，不过也是证据）
#   amfi    umi-pmgr=2，--stop-address 0xfffffff004aaeb54（契约审计钉死的 AMFI 读/OR/写址）：
#           官方要 pc 恰等于它 + x20==nub + x21==0xffffffff，即「原版 AMFI 真的用到了我们发布的 nub」
#   deep    umi-pmgr=2，停 _panic 且跑满超时：AMFI 那句 panic 消失没有、下一个停点是谁、
#           _initproc_spawned 终于是不是 1（launchd 落成 initproc 是本项目的正闸）
# 读址集与 run-systemos-qemu.sh 对齐（官方 analyze 件要的符号一个不缺），所以 deep 档跑完
#   还能直接喂 tools/analyze_umi_systemos_qemu.py——它只在 --screen-diagnostics 档才有 _exit_records。
set -u
MODE=${1:-off}
NAME=${2:-42-pmgr-$MODE}
WS=/home/unixnu/code/umi-work-pin
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
export PATH="$TC/CommandLineTools/usr/bin:$TC/bin:/usr/local/bin:/usr/bin:/bin"
export LC_ALL=C
K=$WS/out/umi-xnu/umi/kernel/qemu-systemos-pmgr.macho
B=$WS/out/umi/trustcache/original-static-system.bundle
LOG=/mnt/e/Code/HackIos/out/probes/pmgr-$MODE.log
exec > >(tee "$LOG") 2>&1

[ -f "$K" ] || { echo "缺内核 $K（先跑 run-kernel-systemos-pmgr.sh + run-umi-prelink.sh qemu-systemos-pmgr）"; exit 1; }
sha256sum "$K" | cut -c1-64 | sed 's/^/  kernel sha=/'

PMGR_ARG=""
STOP=()
TRACE=(--trace _trust_cache_runtime_init --trace _load_init_program --trace _umi_pmgr_run)
TIMEOUT=${TIMEOUT:-900}
case "$MODE" in
  off)       STOP=(--stop _panic) ;;
  lifecycle) PMGR_ARG="umi-pmgr=1"; STOP=(--stop _umi_pmgr_checkpoint) ;;
  publish)   PMGR_ARG="umi-pmgr=2"; STOP=(--stop _umi_pmgr_checkpoint) ;;
  refusal)   PMGR_ARG="umi-pmgr=3"; STOP=(--stop _panic) ;;
  root)      PMGR_ARG="umi-pmgr=2"; STOP=(--stop _IOFindBSDRoot) ;;
  amfi)      PMGR_ARG="umi-pmgr=2"; STOP=(--stop-address 0xfffffff004aaeb54) ;;
  deep)      PMGR_ARG="umi-pmgr=2"; STOP=(--stop _panic) ;;
  *) echo "mode 只认 off|lifecycle|publish|refusal|root|amfi|deep"; exit 1 ;;
esac

ARGS=(--root-volume --systemos-volume --no-vmm-property --owned-memory-mib 320
      --trust-cache "$B"
      --timeout "$TIMEOUT" --capture-screen
      --args "-v keepsyms=1 kt_fixed_zones=120 offline-apfs-load=1 $PMGR_ARG"
      --read-symbol _umi_pmgr_observation:0x80
      --read-symbol _initproc_spawned:4
      --read-symbol _native_owner_cache_status:4
      --read-symbol _native_owner_cache_authorized:4
      --read-symbol _native_owner_cache_native_union:4
      --read-symbol _native_owner_cache_dyld_flags:4
      --read-symbol _umi_owner_root_observation:0x90
      --read-symbol _umi_exec_trace_seen:8
      --read-symbol _umi_exec_trace_observation:0xa0
      --read-symbol _cs_native4k_full_blocks:8
      --read-symbol _cs_native4k_page_checks:8
      --read-symbol _cs_native4k_ready_blobs:8)
# 官方 analyze 件第 60 行无条件读 _exit_records 的 2382 字节（0x94e）；它只在
# --screen-diagnostics 档链得进内核，而挂不存在的符号会让整个 run 起不来，所以按档里有没有它决定。
NM=$TC/CommandLineTools/usr/bin/nm
if [ -x "$NM" ] && "$NM" -n "$K" | grep -q ' _exit_records$'; then
  tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/make-run-umi-qemu-chunked-read.py \
    > /tmp/make-run-umi-qemu-chunked-read.py
  python3 /tmp/make-run-umi-qemu-chunked-read.py --runner "$WS/tools/run_umi_qemu.py" || exit 1
  ARGS+=(--read-symbol _exit_records:0x94e)
  echo "  _exit_records 在档里 -> 挂 0x94e 读址（分段读补丁已就位）"
else
  echo "  缺 _exit_records：官方 analyze 件会在第 60 行崩，这档需要 run-kernel-systemos-pmgr.sh 重编"
fi

echo "== 跑 $NAME（mode=$MODE 旗标='$PMGR_ARG' 停点=${STOP[*]} timeout=${TIMEOUT}s）=="
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/run-umi-qemu.sh > /tmp/run-umi-qemu.sh
cd "$WS" || exit 1
KERNEL=out/umi-xnu/umi/kernel/qemu-systemos-pmgr.macho \
  bash /tmp/run-umi-qemu.sh "$NAME" "${ARGS[@]}" "${STOP[@]}" "${TRACE[@]}"
echo "run_umi_qemu exit=$?"

echo "-- 关键读数 --"
python3 - "$WS/out/umi-qemu/$NAME/gdb-stop.json" <<'PY'
import json,struct,sys
d=json.load(open(sys.argv[1]))
print("  pc =", d.get("pc"), " x0 =", d.get("x0"), " interrupted =", d.get("bounded_timeout_interrupted"))
am=d.get("argument_memory") or {}
for k,v in am.items(): print(f"  argument_memory[{k}] -> {str(v)[:120]!r}")
mem=d.get("memory",{})
def grab(addr):
    for key in mem:
        a,_,ln=key.partition(":")
        if int(a,16)==addr: return bytes.fromhex(mem[key])
    return None
labels=('stage','status','parent_size','own_size','provider','nub','bound_provider',
        'read_before','read_after','own_before','own_after','nub_before','nub_after',
        'attached','registered','mode')
for key in sorted(mem):
    a,_,ln=key.partition(":")
    if int(ln,16)==0x80:
        vals=struct.unpack('<16Q',grab(int(a,16)))
        print("  _umi_pmgr_observation @", key)
        for l,v in zip(labels,vals): print(f"     {l:14s} = {v:#x}" if v>0x1f else f"     {l:14s} = {v}")
for key in sorted(mem):
    a,_,ln=key.partition(":")
    if int(ln,16)==4:
        b=grab(int(a,16))
        if b: print(f"  4字节读址 {a} = {struct.unpack('<I',b)[0]}")
te=d.get("trace_events") or []
print("  trace_events：", [(t.get('symbol') or t.get('name'), t.get('pc'), t.get('elapsed_seconds')) for t in te][-8:])
for k in ("virtio_block_input","virtio_extra_block_input"):
    v=d.get(k)
    print(f"  {k} = {'有' if v else v}")
PY

echo "-- 官方判读 --"
if [ "$MODE" = deep ]; then
  echo "  deep 不是官方 pmgr mode；改喂官方 SystemOS 汇总件（它给 launchd_main_observed 与 status）"
else
  ( cd "$WS" && python3 tools/check_umi_pmgr_observation.py \
      --kernel out/umi-xnu/umi/kernel/qemu-systemos-pmgr.macho \
      --observation out/umi-qemu/$NAME/gdb-stop.json --mode "$MODE" )
  echo "  官方 check exit=$?"
  echo "  （这档不喂 SystemOS 汇总件：停点太早，owner cache 还没落定，断言必然在半路崩）"
fi
if [ "$MODE" = deep ]; then
  echo "-- 官方 SystemOS 汇总件 analyze_umi_systemos_qemu.py --"
  ( cd "$WS" && python3 tools/analyze_umi_systemos_qemu.py out/umi-qemu/$NAME \
      --output out/umi-qemu/$NAME/analysis-$MODE.json ) 2>&1 | tail -45
  echo "  analyze exit=$?"
fi
echo "-- 超时/停点那一眼 pc 在档里叫什么 --"
NM=$TC/CommandLineTools/usr/bin/nm python3 - "$WS/out/umi-qemu/$NAME/gdb-stop.json" "$K" <<'PY'
import json,os,subprocess,sys
d=json.load(open(sys.argv[1])); k=sys.argv[2]
out=subprocess.run([os.environ["NM"],"-n",k],capture_output=True,text=True).stdout
sym={}
for line in out.splitlines():
    row=line.split()
    if len(row)==3: sym.setdefault(int(row[0],16),row[2])
def name(addr):
    at=[a for a in sym if a<=addr]
    return f"{sym[max(at)]}+{addr-max(at):#x}" if at else "?"
print("  pc =",d["pc"],"->",name(int(d["pc"],16)))
for t in (d.get("trace_events") or []):
    print("   trace",t["pc"],"->",name(int(t["pc"],16)),"| lr",t.get("lr"),
          "->",name(int(t["lr"],16)) if t.get("lr") else "?","| elapsed",t.get("elapsed_seconds"))
for f in (d.get("frame_chain") or [])[:6]:
    print("   frame lr",f["lr"],"->",name(int(f["lr"],16)))
PY
cp -f "$WS/out/umi-qemu/$NAME/screen.png" /mnt/e/Code/HackIos/out/screens/$NAME.png 2>/dev/null && \
  echo "  屏照 -> out/screens/$NAME.png"
