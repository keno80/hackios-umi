#!/bin/bash
# U 步之七之五：Data 档取证——官方那对件（run/analyze_umi_data_display_qemu.py）硬要求 legacy_display，
#   而 display 组件的钉值输入 out/umi-xnu/umi/kernel/display-reference.macho 本机不存在（u236 实测：全盘 find 为空，
#   build_umi_data_display.py:70-73 要求它的 sha 与 original_sha256=f18b4df8… 双命中），所以官方件跑不了。
#   本件不放宽判据，只是**照抄官方的 boot-arg 集与符号集**，用本仓既有通路（run_umi_qemu.py 直调）取证，
#   再在本地按官方 analyze 的公式逐条算：
#     data_mounted_writable = status==0 && stage==4 && readonly==0 && ram_block_ready==1
#     种子身份 = owner_data_seed_sha256 == ram_block_seed_sha256 == source-build 里的 sha256
#     actual_ram_writes = native_ram_block_writes > 0
#   要答的问题：Apple 原版 APFS 驱动认不认 Linux（mkapfs）造的容器（stage 走到几、ready 是不是 1）。
# 用法：run-data-qemu.sh [run名，默认 47-data-linux-seed]
#   前置：run-kernel-systemos-data.sh 编完 + run-umi-prelink.sh qemu-systemos-data
#   BYPASS=1 额外挂原版 tunable panic_on_crash_disabled=1（让服务退出不再拖着内核死）
#   STOP=符号 可换停点（默认 _panic）；TIMEOUT 默认 600
#   REGISTRY=1 挂上游观测件本来就有的注册表串通道（--log-registry-strings），把「原版 APFS 到底
#     把哪个卷 UUID 发给了 IOKit、由谁发的」读出来——native_ram_block_volume_seed() 按 UUID 找
#     IOMedia，0 条匹配/多于 1 条/属性不齐/提供者链够不到 NativeRamBlock 四种都表现为 stage=0+ENOENT，
#     只有这条通道能分开。判读件：tools-wsl/evaluate-data-registry-evidence.py
#   REGISTRY_EVENTS=N 同时抬这条通道的事件预算（上游原件写死 128，48 档实测正好掐满，默认 4096）
#   STOP_ADDR=裸指令址 用上游的 --stop-address 直接停在 donor kext 里的裸址上（那段没有符号，
#     --stop/--trace/--also-stop 三个口都要先过 run_umi_qemu.py 的 symbol()，只有 --stop-address 不吃名字）。
#     判读就是停瞬间的通用寄存器：停在 nx_mount 返错分支上，x0 就是原版驱动给容器挂载的返回码。
#   SKIP_HITS=N 跳过前 N 次命中（上游 --skip-target-hits，0..16），用来逐个看同一址上的多次命中
set -u
NAME=${1:-47-data-linux-seed}
WS=/home/unixnu/code/umi-work-pin
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
export PATH="$TC/CommandLineTools/usr/bin:$TC/bin:/usr/local/bin:/usr/bin:/bin"
export LC_ALL=C XNU_TOOLCHAIN_BIN="$TC/CommandLineTools/usr/bin $TC/XcodeDefault.xctoolchain/usr/bin"
K=$WS/out/umi-xnu/umi/kernel/${KNAME:-qemu-systemos-data}.macho
B=$WS/out/umi/trustcache/original-static-system.bundle
LOG=/mnt/e/Code/HackIos/out/probes/data-qemu-$NAME.log
exec > >(tee "$LOG") 2>&1

NM=$TC/CommandLineTools/usr/bin/nm
[ -x "$NM" ] || { echo "缺 nm：$NM"; exit 1; }
[ -f "$K" ] || { echo "缺内核 $K（先跑 run-kernel-systemos-data.sh + run-umi-prelink.sh qemu-systemos-data）"; exit 1; }
BUILD=$K
BUILD=${K%.macho}.source-build.json
[ -f "$BUILD" ] || { echo "缺 $BUILD（--data-ramdisk 的身份就在这份里）"; exit 1; }
sha256sum "$K" | cut -c1-64 | sed 's/^/  kernel sha=/'

SEED=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["data_ramdisk"]["path"])' "$BUILD")
UUID=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["data_ramdisk"]["volume_uuid"])' "$BUILD")
SHA=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["data_ramdisk"]["sha256"])' "$BUILD")
[ -f "$SEED" ] || { echo "缺种子 $SEED"; exit 1; }
echo "  种子 = $SEED"
echo "  卷 UUID = $UUID   logical sha256 = $SHA"
python3 - "$BUILD" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for k in ("profile", "systemos", "owner_root", "pmgr", "screen_diagnostics", "data_ramdisk", "legacy_display"):
    v = d.get(k)
    print(f'  {k} =', (v if k != "data_ramdisk" else {kk: v[kk] for kk in ("bytes", "encoded_bytes", "volume_uuid", "path")}))
PY

echo "== 0. 符号在场性（官方符号集里 display 那批本档不存在，逐个筛）=="
DUMP=$("$NM" -n "$K")
echo "  nm 符号行数=$(echo "$DUMP" | wc -l)"
DATA_SYMBOLS=(native_owner_data_status:4 native_owner_data_stage:4 native_owner_data_readonly:4
              native_owner_data_device:4 native_owner_data_seed_sha256:32
              native_ram_block_ready:4 native_ram_block_bytes:8 native_ram_block_reads:8
              native_ram_block_writes:8 native_ram_block_failures:8 native_ram_block_resident_bytes:8
              native_ram_block_seed_sha256:32 native_owner_cache_status:4 native_owner_cache_authorized:4
              native_owner_cache_native_union:4 initproc_spawned:4 umi_exec_trace_seen:8
              umi_exec_trace_observation:160 boot_progress_display_owned:4
              native_data_persist_state:4 native_data_persist_pages:8
              gDramSize:8 gDramBase:8
              vm_page_free_count:4 vm_page_free_min:4 vm_page_free_target:4
              vm_page_pageable_internal_count:4 vm_page_speculative_count:4
              vm_page_wire_count:4 memorystatus_vm_pressure_level:4
              memorystatus_compressor_space_shortage:4
              memorystatus_available_pages:4 memorystatus_available_pages_critical:4
              memorystatus_available_pages_critical_base:4
              memorystatus_available_pages_critical_idle:4
              memorystatus_available_pages_pressure:4 memorystatus_level:4)
HAS_EXIT=0
if echo "$DUMP" | grep -q ' _exit_records$'; then HAS_EXIT=1; else echo "  注意：本档没有 _exit_records（screen 诊断没链进来？）"; fi
# UMI_GUEST_RAM_MIB：一次同时抬 QEMU 的 -m 与 ADT 的 /chosen/dram-size（两件必须同动，
# 见 tools-wsl/make-run-umi-qemu-guest-ram.py 的说明）。不设就是上游原样 1 GiB。
if [ -n "${UMI_GUEST_RAM_MIB:-}" ]; then
  tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/make-run-umi-qemu-guest-ram.py > /tmp/make-run-umi-qemu-guest-ram.py
  python3 /tmp/make-run-umi-qemu-guest-ram.py --runner "$WS/tools/run_umi_qemu.py" || exit 1
fi
ARGS=(--root-volume --systemos-volume --data-ramdisk "$SEED" --trust-cache "$B"
      --no-vmm-property --owned-memory-mib 320 --timeout "${TIMEOUT:-600}" --capture-screen
      --args "-v keepsyms=1 kt_fixed_zones=120 umi-pmgr=2 boot-progress=2 native-ufs-root=1 offline-apfs-load=1 -apfs_shared_datavolume${BYPASS:+ panic_on_crash_disabled=1}")
if [ -n "${STOP_ADDR:-}" ]; then
  ARGS+=(--stop-address "$STOP_ADDR")
else
  ARGS+=(--stop "${STOP:-_panic}")
fi
[ -n "${SKIP_HITS:-}" ] && ARGS+=(--skip-target-hits "$SKIP_HITS")
for s in "${DATA_SYMBOLS[@]}"; do
  n=${s%%:*}
  if echo "$DUMP" | grep -q " _$n\$"; then ARGS+=(--read-symbol "_$n:${s##*:}"); else echo "  缺符号 $n（本档没编进去）"; fi
done
if [ "$HAS_EXIT" = 1 ]; then
  tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/make-run-umi-qemu-chunked-read.py > /tmp/make-run-umi-qemu-chunked-read.py
  python3 /tmp/make-run-umi-qemu-chunked-read.py --runner "$WS/tools/run_umi_qemu.py" || exit 1
  ARGS+=(--read-symbol _exit_records:0x94e)
fi
if [ "${REGISTRY:-0}" = 1 ]; then
  tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/make-run-umi-qemu-registry-log.py > /tmp/make-run-umi-qemu-registry-log.py
  python3 /tmp/make-run-umi-qemu-registry-log.py --runner "$WS/tools/run_umi_qemu.py" || exit 1
  # 上游把这条通道的事件预算写死在 128，48 档实测正好掐在 128（最后一发 UUID 属性还在
  # 12.959 秒）——负证据不成立，所以同一档里把预算一起抬起来。
  tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/make-run-umi-qemu-registry-budget.py > /tmp/make-run-umi-qemu-registry-budget.py
  python3 /tmp/make-run-umi-qemu-registry-budget.py --runner "$WS/tools/run_umi_qemu.py" \
    --events "${REGISTRY_EVENTS:-4096}" || exit 1
  ARGS+=(--log-registry-strings)
fi

echo
echo "== 1. 跑 $NAME（BYPASS=${BYPASS:-0} STOP=${STOP:-_panic} STOP_ADDR=${STOP_ADDR:-（未用）} SKIP_HITS=${SKIP_HITS:-0} REGISTRY=${REGISTRY:-0}）=="
cd "$WS" || exit 1
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/run-umi-qemu.sh > /tmp/run-umi-qemu.sh
KERNEL=out/umi-xnu/umi/kernel/${KNAME:-qemu-systemos-data}.macho bash /tmp/run-umi-qemu.sh "$NAME" "${ARGS[@]}"
echo "run_umi_qemu exit=$?"

echo
echo "== 1.5 客存几何核对（三处必须一致：环境 / QEMU 实际 -m / 内核吃的 ADT）=="
python3 - "$WS/out/umi-qemu/$NAME" "${UMI_GUEST_RAM_MIB:-（未设，上游默认 1024）}" <<'PY'
import json, struct, sys
run, want = sys.argv[1], sys.argv[2]
sys.path.insert(0, "/home/unixnu/code/umi-work-pin/devices/umi/scripts")
from umi_adt import decode
adt = decode(open(f"{run}/esp/EFI/UniXNU/Payloads/kernel.macho.adt", "rb").read())
chosen = adt.at("/chosen").properties
for name in ("dram-base", "dram-size"):
    v = struct.unpack("<Q", chosen[name])[0]
    print(f"  ADT /chosen/{name} = {v} ({v / 1024**2:.0f} MiB)")
stop = json.load(open(f"{run}/gdb-stop.json"))
print("  gdb-stop 记的 qemu_memory_mib =", stop.get("qemu_memory_mib", "缺"))
print("  环境 UMI_GUEST_RAM_MIB =", want)
PY

echo
echo "== 2. 按官方 analyze 的公式逐条算 =="
python3 - "$WS/out/umi-qemu/$NAME/gdb-stop.json" "$K" "$BUILD" <<'PY'
import hashlib, json, os, re, struct, subprocess, sys
stop, kernel, build = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(stop)); src = json.load(open(build))
seed = src["data_ramdisk"]
sym = {}
out = subprocess.run(["xcrun", "nm", "-n", kernel], capture_output=True, text=True).stdout
for line in out.splitlines():
    p = line.split()
    if len(p) == 3:
        sym.setdefault(p[2], int(p[0], 16))
mem = d.get("memory", {})
def raw(name, size):
    k = f"{sym['_' + name]:#x}:{size:x}"
    return bytes.fromhex(mem[k]) if k in mem else None
def val(name, size=4):
    b = raw(name, size)
    return None if b is None else int.from_bytes(b, "little")
m = {}
for n in sorted({k[1:] for k in sym if k.startswith("_native_") or k.startswith("_umi_exec") or k.startswith("_initproc") or k.startswith("_gDram")}):
    for size in (4, 8):
        if raw(n, size) is not None:
            m.setdefault(n, val(n, size))
print("  pc =", d.get("pc"), " 超时停 =", d.get("bounded_timeout_interrupted"))
print("  符号缺失（本档没编进去）=", [n.split(":")[0] for n in
      "native_owner_data_status native_owner_data_stage native_owner_data_readonly native_ram_block_ready".split()
      if "_" + n not in sym])
for n in ("native_owner_data_status", "native_owner_data_stage", "native_owner_data_readonly",
          "native_owner_data_device", "native_ram_block_ready", "native_ram_block_bytes",
          "native_ram_block_reads", "native_ram_block_writes", "native_ram_block_failures",
          "native_ram_block_resident_bytes", "native_owner_cache_status", "native_owner_cache_authorized",
          "native_owner_cache_native_union", "initproc_spawned",
          "native_data_persist_state", "native_data_persist_pages",
          "gDramSize", "gDramBase"):
    print(f"  {n} =", m.get(n, "缺"))
a = raw("native_owner_data_seed_sha256", 32); b = raw("native_ram_block_seed_sha256", 32)
print("  owner_data_seed_sha256 =", a.hex() if a else "缺")
print("  ram_block_seed_sha256  =", b.hex() if b else "缺")
print("  source-build 钉的 sha   =", seed["sha256"])
print("  身份三合一 =", "PASS" if (a and b and a.hex() == b.hex() == seed["sha256"]) else "不符/还没挂上")
mounted = (m.get("native_owner_data_status") == 0 and m.get("native_owner_data_stage") == 4
           and m.get("native_owner_data_readonly") == 0 and m.get("native_ram_block_ready") == 1)
print("  官方口径 data_mounted_writable =", mounted)
print("  官方口径 actual_ram_writes_observed =", (m.get("native_ram_block_writes") or 0) > 0)
print("  官方口径 launchd_main_observed =", m.get("initproc_spawned") == 1)
seen = raw("umi_exec_trace_seen", 8)
if seen:
    w = int.from_bytes(seen, "little")
    print("  umi_exec_trace_seen =", hex(w), " phase 位 =", [i for i in range(64) if w >> i & 1])
    print("  panic_recorded =", bool(w & (1 << 5)), " critical_exit_recorded =", bool(w & (1 << 8)))
obs = raw("umi_exec_trace_observation", 160)
if obs:
    print("  observation(20Q) =", [hex(x) if x > 0xffffffff else x for x in struct.unpack("<20Q", obs)])
ex = raw("exit_records", 2382)
if ex:
    print("  process_exit_counts =", list(struct.unpack_from("<3I", ex)))
    print("  recent_process_exits =", [ex[12 + i * 120:12 + (i + 1) * 120].split(b"\0", 1)[0].decode(errors="replace") for i in range(4)])
    print("  failed_process_exits =", [ex[492 + i * 120:492 + (i + 1) * 120].split(b"\0", 1)[0].decode(errors="replace") for i in range(3)])
    tail = [s.decode() for s in re.findall(rb"[ -~]{4,}", ex[852:])]
    print("  尾串 =", tail[:12] if tail else "（全零）")
PY
cp -f "$WS/out/umi-qemu/$NAME/screen.png" /mnt/e/Code/HackIos/out/screens/$NAME.png 2>/dev/null && \
  echo "  屏照 -> out/screens/$NAME.png"

if [ "${REGISTRY:-0}" = 1 ]; then
  echo
  echo "== 3. 注册表发布面判读（原版驱动到底把哪个卷 UUID 发给了 IOKit、由谁发的）=="
  tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/evaluate-data-registry-evidence.py > /tmp/eval-data-registry.py
  python3 /tmp/eval-data-registry.py "$WS/out/umi-qemu/$NAME" "$K" "$BUILD"
fi
