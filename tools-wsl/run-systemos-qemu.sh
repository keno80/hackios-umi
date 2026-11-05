#!/bin/bash
# U 步之五之二：SystemOS 档在 QEMU 里跑「OS 根 + SystemOS cryptex 只读 union + 原版 trustcache」
# 用法：run-systemos-qemu.sh [run名，默认 39-systemos-union] [停点符号，默认 _panic]
#   探路跑法：先停 _panic——没过闸会 panic，过了闸是超时（两者都是信息）
# 前置：run-kernel-systemos.sh 编完 + run-umi-prelink qemu-systemos-union
# 判读：官方 tools/analyze_umi_systemos_qemu.py（它要的两块只读盘由 --root-volume --systemos-volume 给）
set -u
NAME=${1:-39-systemos-union}
STOP=${2:-_panic}
TIMEOUT=${TIMEOUT:-900}
FINISH=${FINISH:-0}
WS=/home/unixnu/code/umi-work-pin
K=${KERNEL:-$WS/out/umi-xnu/umi/kernel/qemu-systemos-union.macho}
B=$WS/out/umi/trustcache/original-static-system.bundle
LOG=/mnt/e/Code/HackIos/out/probes/systemos-$NAME.log
exec > >(tee "$LOG") 2>&1

echo "== 内核与 bundle"
[ -f "$K" ] || { echo "缺内核 $K（先跑 run-kernel-systemos.sh + run-umi-prelink qemu-systemos-union）"; exit 1; }
sha256sum "$K" | cut -c1-64 | sed 's/^/  kernel sha=/'
sha256sum "$B" | cut -c1-64 | sed 's/^/  bundle sha=/'

# 官方判读件要读的观测符号，一个不缺地挂上
# 唯一不挂的是 _exit_records：它是 boot-progress 包（--screen-diagnostics）里的 static，
# 本档没链进内核，读它会 `missing exact kernel symbol`；官方 analyze 件第 59 行正是要它，
# 所以「跑官方 analyze 件」的前置是补 --gic-diagnostics --screen-diagnostics 重编一档。
ARGS=(--root-volume --systemos-volume --no-vmm-property --owned-memory-mib 320
      --trust-cache "$B"
      --timeout "$TIMEOUT" --capture-screen
      --args "-v keepsyms=1 kt_fixed_zones=120 offline-apfs-load=1"
      --read-symbol _umi_owner_root_observation:0x90
      --read-symbol _native_owner_cache_status:4
      --read-symbol _native_owner_cache_authorized:4
      --read-symbol _native_owner_cache_native_union:4
      --read-symbol _native_owner_cache_dyld_flags:4
      --read-symbol _initproc_spawned:4
      --read-symbol _umi_exec_trace_seen:8
      --read-symbol _umi_exec_trace_observation:0xa0
      --read-symbol _cs_native4k_full_blocks:8
      --read-symbol _cs_native4k_page_checks:8
      --read-symbol _cs_native4k_ready_blobs:8
      --trace _trust_cache_runtime_init --trace _load_init_program)
if [ "$FINISH" = 1 ]; then ARGS+=(--stop "$STOP" --finish); else ARGS+=(--stop "$STOP"); fi

echo "== 跑 $NAME（停点 $STOP，timeout ${TIMEOUT}s）"
KERNEL=out/umi-xnu/umi/kernel/$(basename "$K") bash /tmp/run-umi-qemu.sh "$NAME" "${ARGS[@]}"
echo "-- 证据 --"
ls -l "$WS/out/umi-qemu/$NAME"
echo "-- uart 尾 30 行 --"
tail -30 "$WS/out/umi-qemu/$NAME/gdb-uart.log" 2>/dev/null
echo "-- 关键观测键 --"
python3 - "$WS/out/umi-qemu/$NAME/gdb-stop.json" <<'PY'
import json, struct, sys
d = json.load(open(sys.argv[1]))
mem = d.get("memory", {})
print("  pc =", d.get("pc"), " x0 =", d.get("x0"),
      " interrupted =", d.get("bounded_timeout_interrupted"))
print("  stop =", d.get("stop"), " threads =", d.get("thread_count"))
for k in ("virtio_block_input", "virtio_extra_block_input"):
    v = d.get(k)
    print(f"  {k} = {v}")
def grab(addr, n):
    for key in mem:
        a, _, ln = key.partition(":")
        if int(a, 16) == addr and int(ln, 16) >= n:
            return bytes.fromhex(mem[key])[:n]
    return None
# 符号址从 provenance 里不好取，这里按已有键反查：打印所有长度>=4 的键值前 8 字节
print("  -- 观测面原始键（前 24 个）--")
for key in sorted(mem)[:24]:
    print(f"     {key} = {mem[key][:32]}")
PY
cp -f "$WS/out/umi-qemu/$NAME/screen.png" /mnt/e/Code/HackIos/out/screens/$NAME.png 2>/dev/null
echo "  屏照 -> out/screens/$NAME.png"
