#!/bin/bash
# U 步之七之一：不重编的归因深跑——用原版 XNU 自带 tunable 关掉「致命关键进程退出」这条 panic
#   判据出处：bsd/kern/kern_exit.c:1705 `static TUNABLE(bool, panic_on_crash_disabled, "panic_on_crash_disabled", false)`，
#   本机现有 pmgr 档内核里 ___startup_TUNABLES_entry_panic_on_crash_disabled_1705 与串
#   "panic-on-crash disabled via boot-arg" 都在（out/probes/u229），所以加一个 boot-arg 就生效，不用重编。
#   目的不是「修好」tzinit，而是看清这道闸后面还有什么：tzinit 仍然会 EROFS 退 30，只是内核不再陪着死。
# 用法：run-tzinit-bypass-qemu.sh [run名，默认 46-tzinit-bypass]；TIMEOUT=600 可覆盖
set -u
NAME=${1:-46-tzinit-bypass}
WS=/home/unixnu/code/umi-work-pin
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
export PATH="$TC/CommandLineTools/usr/bin:$TC/bin:/usr/local/bin:/usr/bin:/bin"
export LC_ALL=C
K=$WS/out/umi-xnu/umi/kernel/qemu-systemos-pmgr.macho
B=$WS/out/umi/trustcache/original-static-system.bundle
LOG=/mnt/e/Code/HackIos/out/probes/tzinit-bypass-$NAME.log
exec > >(tee "$LOG") 2>&1

[ -f "$K" ] || { echo "缺内核 $K"; exit 1; }
sha256sum "$K" | cut -c1-64 | sed 's/^/  kernel sha=/'
NM=$TC/CommandLineTools/usr/bin/nm
[ -x "$NM" ] || { echo "缺 nm：$NM"; exit 1; }
DUMP=$("$NM" -n "$K")
for s in _panic _exit_records _initproc_spawned _umi_exec_trace_observation; do
  echo "$DUMP" | grep -q " $s\$" && echo "  在位 $s" || { echo "  缺 $s"; exit 1; }
done

# 大读 _exit_records（2382 B）要分段读补丁，否则本机 gdbstub 回 E22
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/make-run-umi-qemu-chunked-read.py > /tmp/make-run-umi-qemu-chunked-read.py
python3 /tmp/make-run-umi-qemu-chunked-read.py --runner "$WS/tools/run_umi_qemu.py" || exit 1

ARGS=(--root-volume --systemos-volume --no-vmm-property --owned-memory-mib 320
      --trust-cache "$B"
      --timeout "${TIMEOUT:-600}" --capture-screen
      --args "-v keepsyms=1 kt_fixed_zones=120 offline-apfs-load=1 umi-pmgr=2 boot-progress=2 panic_on_crash_disabled=1"
      --stop _panic
      --read-symbol _initproc_spawned:4
      --read-symbol _umi_exec_trace_seen:8
      --read-symbol _umi_exec_trace_observation:0xa0
      --read-symbol _exit_records:0x94e
      --read-symbol _umi_boot_progress_samples:0x100
      --read-symbol _boot_progress_frequency:8
      --read-symbol _native_owner_cache_status:4
      --read-symbol _native_owner_cache_authorized:4
      --read-symbol _native_owner_cache_native_union:4
      --read-symbol _cs_native4k_full_blocks:8
      --read-symbol _cs_native4k_page_checks:8
      --read-symbol _cs_native4k_ready_blobs:8)

echo "== 1. 跑 $NAME（boot-arg 带 panic_on_crash_disabled=1）=="
cd "$WS" || exit 1
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/run-umi-qemu.sh > /tmp/run-umi-qemu.sh
KERNEL=out/umi-xnu/umi/kernel/qemu-systemos-pmgr.macho bash /tmp/run-umi-qemu.sh "$NAME" "${ARGS[@]}"
echo "run_umi_qemu exit=$?"

echo
echo "== 2. 读数：停在哪、有没有真 panic、退出记录里都有谁 =="
NMADDR=$TC/CommandLineTools/usr/bin/nm python3 - "$WS/out/umi-qemu/$NAME/gdb-stop.json" "$K" <<'PY'
import json,os,re,struct,subprocess,sys
d=json.load(open(sys.argv[1])); k=sys.argv[2]
out=subprocess.run([os.environ["NMADDR"],"-n",k],capture_output=True,text=True).stdout
sym={}
for line in out.splitlines():
    p=line.split()
    if len(p)==3: sym.setdefault(p[2],int(p[0],16))
mem=d.get("memory",{})
def raw(name,nbytes):
    return bytes.fromhex(mem[f"{sym['_'+name]:#x}:{nbytes:x}"]) if f"{sym['_'+name]:#x}:{nbytes:x}" in mem else None
print("  pc =",d.get("pc")," symbol =",[n for n,a in sym.items() if a==d.get("pc")][:1])
print("  超时停 =",d.get("bounded_timeout_interrupted"))
for ev in (d.get("function_returns") or [])[:8]:
    print("   事件",ev.get("symbol")," pc=",hex(ev.get("pc",0))," 耗时=",ev.get("elapsed_seconds"))
seen=raw("umi_exec_trace_seen",8)
if seen:
    v=struct.unpack("<2Q",seen)
    bits=[i for i in range(128) if (v[1]<<64|v[0])>>i&1] if isinstance(v,tuple) else []
    word=v[0]|(v[1]<<64)
    print("  umi_exec_trace_seen =",hex(v[0]),hex(v[1])," 置位 =",[i for i in range(64) if word>>i&1])
obs=raw("umi_exec_trace_observation",160)
if obs:
    q=struct.unpack("<20Q",obs)
    print("  observation(20Q) =",[hex(x) if x>0xffffffff else x for x in q])
ex=raw("exit_records",2382)
if ex:
    total,failed,crashes=struct.unpack_from("<3I",ex)
    print("  _exit_records total/failed/crashes =",total,failed,crashes)
    for i in range(4):
        s=ex[12+i*120:12+(i+1)*120].split(b"\0",1)[0].decode(errors="replace")
        print(f"   recent[{i}] = {s!r}")
    for i in range(3):
        s=ex[492+i*120:492+(i+1)*120].split(b"\0",1)[0].decode(errors="replace")
        print(f"   failed[{i}] = {s!r}")
    print("   尾串 =",[s.decode() for s in re.findall(rb"[ -~]{4,}",ex[852:])][:12])
print("  initproc_spawned =",struct.unpack("<I",raw("initproc_spawned",4))[0] if raw("initproc_spawned",4) else "缺")
for n in ("native_owner_cache_status","native_owner_cache_authorized","native_owner_cache_native_union"):
    b=raw(n,4); print(f"  {n} =",struct.unpack("<I",b)[0] if b else "缺")
for n in ("cs_native4k_full_blocks","cs_native4k_page_checks","cs_native4k_ready_blobs"):
    b=raw(n,8); print(f"  {n} =",struct.unpack("<Q",b)[0] if b else "缺")
PY
cp -f "$WS/out/umi-qemu/$NAME/screen.png" /mnt/e/Code/HackIos/out/screens/$NAME.png 2>/dev/null && \
  echo "  屏照 -> out/screens/$NAME.png"
