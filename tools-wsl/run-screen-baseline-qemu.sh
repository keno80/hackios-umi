#!/bin/bash
# U 步之六之四：官方 screen 资格化件（check_umi_screen_qemu.py）在 --pmgr 档上跑通
# 用法：run-screen-baseline-qemu.sh [run名，默认 44-screen-baseline]
#   前置：run-kernel-systemos-pmgr.sh 编完 + run-umi-prelink.sh qemu-systemos-pmgr
#   （官方件第 37 行硬要求 source-build.json 里 screen_diagnostics && gic_diagnostics && pmgr 三者同开，
#     这就是 U 步之三一直产不出 out/umi/screen-qemu-baseline.json 的原因）
#   停点为什么是 _umi_boot_progress_checkpoint_eight：官方第 34 行把 pc 钉成这个符号，
#     它在 BootProgress.c:996「第 8 次画屏 pass」时被调；同时第 31 行要求不是超时停，
#     所以只能真跑到那一 pass，不能靠 timeout 蒙
# 必须有 boot-arg boot-progress=2：链进内核的是生成件 BootProgress.providers.c:716 的
#   boot_progress_init()，它第一行就是 PE_parse_boot_argn("boot-progress",&opt) 且只认 1/2，
#   否则整个仪表（frequency/anchor/samples/observation）恒零、停点永不触发（u218/u219/u221 实测；
#   上游 run_umi_data_display_qemu.py:28 与 make_umi_payload.py:58 钉的就是 boot-progress=2）
set -u
NAME=${1:-44-screen-baseline}
WS=/home/unixnu/code/umi-work-pin
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
export PATH="$TC/CommandLineTools/usr/bin:$TC/bin:/usr/local/bin:/usr/bin:/bin"
export LC_ALL=C
K=$WS/out/umi-xnu/umi/kernel/qemu-systemos-pmgr.macho
B=$WS/out/umi/trustcache/original-static-system.bundle
LOG=/mnt/e/Code/HackIos/out/probes/screen-baseline-$NAME.log
exec > >(tee "$LOG") 2>&1

[ -f "$K" ] || { echo "缺内核 $K（先跑 run-kernel-systemos-pmgr.sh + run-umi-prelink.sh qemu-systemos-pmgr）"; exit 1; }
sha256sum "$K" | cut -c1-64 | sed 's/^/  kernel sha=/'

echo "== 0. 官方件吃的四组读址与停点符号是否都在这档里 =="
NM=$TC/CommandLineTools/usr/bin/nm
[ -x "$NM" ] || { echo "缺 nm：$NM"; exit 1; }
DUMP=$("$NM" -n "$K")
echo "  nm 符号行数=$(echo "$DUMP" | wc -l)"
MISS=0
for s in _umi_boot_progress_checkpoint_eight _umi_boot_progress_samples \
         _boot_progress_frequency _boot_progress_observation _umi_boot_progress_anchor; do
  if echo "$DUMP" | grep -q " $s\$"; then echo "  在位 $s"; else echo "  缺 $s"; MISS=$((MISS+1)); fi
done
[ "$MISS" = 0 ] || { echo "  缺 $MISS 个符号，官方 screen 件跑不起来"; exit 1; }

ARGS=(--root-volume --systemos-volume --no-vmm-property --owned-memory-mib 320
      --trust-cache "$B"
      --timeout "${TIMEOUT:-900}" --capture-screen
      --args "-v keepsyms=1 kt_fixed_zones=120 offline-apfs-load=1 umi-pmgr=2 boot-progress=2"
      --stop _umi_boot_progress_checkpoint_eight
      --read-symbol _umi_boot_progress_samples:0x100
      --read-symbol _boot_progress_frequency:8
      --read-symbol _boot_progress_observation:0xc0
      --read-symbol _umi_boot_progress_anchor:0x18
      --read-symbol _boot_progress_display_owned:4
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

# boot-progress 一旦真开起来，_exit_records（bp_exits，2382 B）才可能有内容：
#   这是上一轮拿不到 tzinit 退出原因的那面。大读要走分段读补丁，否则 gdbstub 回 E22。
if "$NM" -n "$K" | grep -q ' _exit_records$'; then
  tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/make-run-umi-qemu-chunked-read.py > /tmp/make-run-umi-qemu-chunked-read.py
  python3 /tmp/make-run-umi-qemu-chunked-read.py --runner "$WS/tools/run_umi_qemu.py" || exit 1
  ARGS+=(--read-symbol _exit_records:0x94e)
  echo "  _exit_records 在位 -> 挂 0x94e 读址（分段读补丁已就位）"
fi

echo "== 1. 跑 $NAME =="
cd "$WS" || exit 1
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/run-umi-qemu.sh > /tmp/run-umi-qemu.sh
KERNEL=out/umi-xnu/umi/kernel/qemu-systemos-pmgr.macho bash /tmp/run-umi-qemu.sh "$NAME" "${ARGS[@]}"
echo "run_umi_qemu exit=$?"

echo
echo "== 2. 官方 screen 资格化件 =="
python3 tools/check_umi_screen_qemu.py --run out/umi-qemu/$NAME \
  --kernel out/umi-xnu/umi/kernel/qemu-systemos-pmgr.macho 2>&1 | tail -40
echo "  check_umi_screen_qemu exit=$?"

echo
echo "== 3. 读数（samples 两趟 16 字）=="
NMADDR=$TC/CommandLineTools/usr/bin/nm python3 - "$WS/out/umi-qemu/$NAME/gdb-stop.json" "$K" <<'PY'
import json,os,struct,subprocess,sys
d=json.load(open(sys.argv[1])); k=sys.argv[2]
out=subprocess.run([os.environ["NMADDR"],"-n",k],capture_output=True,text=True).stdout
sym={}
for line in out.splitlines():
    p=line.split()
    if len(p)==3: sym.setdefault(p[2],int(p[0],16))
mem=d.get("memory",{})
def read(name,count):
    key=f"{sym[name]:#x}:{count*8:x}"
    return struct.unpack("<"+"Q"*count,bytes.fromhex(mem[key])) if key in mem else None
print("  pc =",d.get("pc")," interrupted =",d.get("bounded_timeout_interrupted"))
samples=read("_umi_boot_progress_samples",32)
rendered=read("_boot_progress_observation",24)
print("  samples(32Q) =",[hex(x) if x>0xffffffff else x for x in samples] if samples else "缺")
print("  observation(24Q) =",[hex(x) if x>0xffffffff else x for x in rendered] if rendered else "缺")
first,last=(samples[:16],samples[16:]) if samples else (None,None)
freq=read("_boot_progress_frequency",1)
anchor=read("_umi_boot_progress_anchor",3)
print("  frequency =",freq[0] if freq else "缺")
print("  anchor =",[hex(x) for x in anchor] if anchor else "缺")
if first and last and freq:
    print("  两趟 pass 计数 =",first[2],"->",last[2]," elapsed =",round((last[15]-first[15])/freq[0],3),"s")
    print("  宽高/行字节 第一趟 =",first[6:9]," 末趟 =",last[6:9]," [2,1,providers] 末趟 =",last[12:15])
# _exit_records（bp_exits，2382 B）：上一轮全零的那面。这里不猜布局，只抽可读串，
#   要的是 tzinit 那次退出的 reason 串（exit status 30 一直没有可读原因）。
key = f"{sym['_exit_records']:#x}:94e" if "_exit_records" in sym else None
if key and key in mem:
    import re
    b = bytes.fromhex(mem[key])
    runs = [s.decode() for s in re.findall(rb"[ -~]{4,}", b)]
    print(f"  _exit_records 前 24 字节 = {b[:24].hex()}")
    print("  可读串 =", runs[:14] if runs else "（仍全零/无串）")
else:
    print("  _exit_records 没读到（键缺）")
PY
cp -f "$WS/out/umi-qemu/$NAME/screen.png" /mnt/e/Code/HackIos/out/screens/$NAME.png 2>/dev/null && \
  echo "  屏照 -> out/screens/$NAME.png"
[ -f "$WS/out/umi/screen-qemu-baseline.json" ] && { echo "== 4. 官方 baseline 件 =="; head -30 "$WS/out/umi/screen-qemu-baseline.json"; }
