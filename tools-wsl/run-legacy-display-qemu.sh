#!/bin/bash
# U 步之九之五：legacy-display 档取证——照官方 run_umi_data_display_qemu.py 的旗标集与符号集跑，
#   再用官方 analyze_umi_data_display_qemu.py 判读（判据一个字不改）。
#
# 为什么不直调官方 runner：它第 34 行把 --owned-memory-mib 写死 320。
#   U 步之八已实测判死——320 MiB 时 prelink 内核 + dyld shared cache + 三个 APFS 窗全 wired，
#   wire 吃掉池子 91%，jetsam 的 available<=critical（门槛按 max_mem=ADT darwinboot-memory-size 算）
#   字面成立，环内 7 发全是 ns=1 sub=4；54/55 单变量 A/B 把 owned 抬到 512 才清零。
#   观测件 make-run-umi-qemu-guest-ram.py 只把 env 换成 argparse 的**默认值**，显式 320 会盖掉它，
#   所以这里由本件按同一套旗标自己拼命令。其余全部逐字对齐官方：
#     boot args = 官方第 26-29 行（sheng board.toml 里挑 offline-legacy-* + offline-mobile-graphics-load=1，
#                 再加 -v keepsyms=1 kt_fixed_zones=120 umi-pmgr=2 boot-progress=2 native-ufs-root=1
#                 offline-apfs-load=1 -apfs_shared_datavolume）
#     符号集     = 官方第 40-64 行的 symbols 字典，运行时用 ast 从官方件里取，杜绝手抄漂移
#     停点       = 官方第 35-39 行（init 停 _execve，runtime 停 _ml_panic_trap_to_debugger，
#                 两档都 --also-stop _native_legacy_backend_guard）
#     三窗只读盘 + --trust-cache + --no-vmm-property --accel tcg 同官方
#   官方判读件硬要求的三条 provenance 旗标本机恒为 false（run_umi_qemu.py:343-344，
#   --no-vmm-property 让 vmm_property_declared 取非），所以这条路没有被我们的观测件污染。
#
# 用法：run-legacy-display-qemu.sh RUN名 [init|runtime]
#   前置：run-kernel-systemos-display.sh 编完 + run-umi-prelink.sh <同一档名>
#   KNAME=prelink 基名（默认 qemu-systemos-display）
#   TIMEOUT 默认 900（runtime）/ 300（init）；OWNED_MIB 默认 512；GUEST_RAM_MIB 默认 2048
#   BYPASS=1 额外挂原版 tunable panic_on_crash_disabled=1（服务退出不再拖着内核死）
set -u
NAME=${1:-56-legacy-display-runtime}
STAGE=${2:-runtime}
WS=/home/unixnu/code/umi-work-pin
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
export PATH="$TC/CommandLineTools/usr/bin:$TC/bin:/usr/local/bin:/usr/bin:/bin"
export LC_ALL=C XNU_TOOLCHAIN_BIN="$TC/CommandLineTools/usr/bin $TC/XcodeDefault.xctoolchain/usr/bin"
KBASE=${KNAME:-qemu-systemos-display}
K=$WS/out/umi-xnu/umi/kernel/$KBASE.macho
B=$WS/out/umi/trustcache/original-static-system.bundle
OWNED=${OWNED_MIB:-512}
GUEST=${GUEST_RAM_MIB:-2048}
case "$STAGE" in
  init)    TIMEOUT=${TIMEOUT:-300}  STOPSYM=_execve ;;
  runtime) TIMEOUT=${TIMEOUT:-900}  STOPSYM=_ml_panic_trap_to_debugger ;;
  *) echo "停手：STAGE 只认 init|runtime，给了 $STAGE"; exit 1 ;;
esac
LOG=/mnt/e/Code/HackIos/out/probes/legacy-display-qemu-$NAME.log
exec > >(tee "$LOG") 2>&1

NM=$TC/CommandLineTools/usr/bin/nm
[ -x "$NM" ] || { echo "停手：缺 $NM（判符号必须用 cctools 那份 nm）"; exit 1; }
[ -f "$K" ] || { echo "停手：缺内核 $K（先跑 run-kernel-systemos-display.sh + run-umi-prelink.sh $KBASE）"; exit 1; }
[ -f "$B" ] || { echo "停手：缺 trustcache 原件 $B"; exit 1; }
OFFICIAL=$WS/tools/run_umi_data_display_qemu.py
JUDGE=$WS/tools/analyze_umi_data_display_qemu.py
[ -f "$OFFICIAL" ] && [ -f "$JUDGE" ] || { echo "停手：缺官方取件/判件"; exit 1; }
BUILD=${K%.macho}.source-build.json
[ -f "$BUILD" ] || { echo "停手：缺 $BUILD"; exit 1; }
sha256sum "$K" | cut -c1-64 | sed 's/^/  kernel sha=/'

# 官方 runner 的三条硬断言先自己验一遍（它吃的是 prelink 件的 .source-build.json）
python3 - "$BUILD" <<'PY' || { echo "停手：source-build 不满足官方 runner 第 24-25 行"; exit 1; }
import json, sys
d = json.load(open(sys.argv[1]))
assert d["profile"] == "qemu" and not d["early_trace"], (d["profile"], d.get("early_trace"))
assert d["legacy_display"] and d["data_ramdisk"] and d["systemos"], \
    (d.get("legacy_display"), bool(d.get("data_ramdisk")), d.get("systemos"))
for k in ("pmgr", "gic_diagnostics", "screen_diagnostics", "owner_root", "crypto_bootstrap"):
    print(f"  {k} =", d.get(k))
print("  data_ramdisk =", {k: d["data_ramdisk"][k] for k in ("path", "volume_uuid", "bytes", "encoded_bytes", "sha256")})
PY
SEED=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["data_ramdisk"]["path"])' "$BUILD")
[ -f "$SEED" ] || { echo "停手：缺种子 $SEED"; exit 1; }
echo "  种子 = $SEED"

echo
echo "== 1. 符号在场性（官方符号集逐个查，缺就是这档没编进去）=="
DUMP=$("$NM" -n "$K")
echo "  nm 符号行数=$(printf '%s\n' "$DUMP" | wc -l)"
# 从官方件里用 ast 取 symbols 字典：长度逐个对齐，杜绝手抄
python3 - "$OFFICIAL" > /tmp/official-symbols.txt <<'PY' || { echo "停手：从官方件取不到 symbols 字典"; exit 1; }
import ast, sys
tree = ast.parse(open(sys.argv[1]).read())
for node in ast.walk(tree):
    if isinstance(node, ast.Assign) and getattr(node.targets[0], "id", "") == "symbols":
        for k, v in zip(node.value.keys, node.value.values):
            print(f"{k.value}:{v.value}")
        break
PY
MISSING=0
while IFS=: read -r n sz; do
  if printf '%s\n' "$DUMP" | grep -q " _${n}\$"; then
    echo "  在位  _${n}:${sz}"
  else
    echo "  ★缺   _${n}:${sz}"; MISSING=$((MISSING + 1))
  fi
done < /tmp/official-symbols.txt
echo "  官方符号集共 $(wc -l < /tmp/official-symbols.txt) 枚，缺 $MISSING 枚"
[ "$MISSING" = 0 ] || { echo "停手：官方符号集不齐，跑了也是半成品"; exit 1; }

echo
echo "== 2. boot args（照官方第 26-29 行从 sheng board.toml 挑）=="
python3 - "$WS" "${BYPASS:-0}" > /tmp/legacy-display-bootargs.txt <<'PY' || { echo "停手：取不到 sheng board.toml 的 kernel_args"; exit 1; }
import pathlib, sys, tomllib
ws, bypass = sys.argv[1:3]
board = tomllib.loads((pathlib.Path(ws) / "sources/UniXNU-sheng/board.toml").read_text())
display_args = [a for a in board["payload"]["kernel_args"]
                if a.startswith("offline-legacy-") or a == "offline-mobile-graphics-load=1"]
boot = ["-v", "keepsyms=1", "kt_fixed_zones=120", "umi-pmgr=2", "boot-progress=2",
        "native-ufs-root=1", "offline-apfs-load=1", "-apfs_shared_datavolume", *display_args]
if bypass == "1":
    boot.append("panic_on_crash_disabled=1")
print(" ".join(boot))
PY
read -r BOOTARGS < /tmp/legacy-display-bootargs.txt
echo "  $BOOTARGS"

# 两条旋钮都要的观测件（幂等；不设也是上游几何）
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/make-run-umi-qemu-guest-ram.py > /tmp/make-run-umi-qemu-guest-ram.py
UMI_GUEST_RAM_MIB=$GUEST UMI_OWNED_MEMORY_MIB=$OWNED python3 /tmp/make-run-umi-qemu-guest-ram.py \
  --runner "$WS/tools/run_umi_qemu.py" || exit 1
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/make-run-umi-qemu-chunked-read.py > /tmp/make-run-umi-qemu-chunked-read.py
python3 /tmp/make-run-umi-qemu-chunked-read.py --runner "$WS/tools/run_umi_qemu.py" || exit 1

ARGS=(--root-volume --systemos-volume --data-ramdisk "$SEED" --trust-cache "$B"
      --no-vmm-property --owned-memory-mib "$OWNED" --timeout "$TIMEOUT" --capture-screen
      --args "$BOOTARGS" --stop "$STOPSYM" --also-stop _native_legacy_backend_guard)
if [ "$STAGE" = init ]; then
  ARGS+=(--also-stop _ml_panic_trap_to_debugger)
fi
while IFS=: read -r n sz; do ARGS+=(--read-symbol "_$n:$sz"); done < /tmp/official-symbols.txt

echo
echo "== 3. 跑 $NAME（STAGE=$STAGE TIMEOUT=$TIMEOUT OWNED=$OWNED GUEST=$GUEST BYPASS=${BYPASS:-0}）=="
cd "$WS" || exit 1
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/run-umi-qemu.sh > /tmp/run-umi-qemu.sh
KERNEL=out/umi-xnu/umi/kernel/$KBASE.macho bash /tmp/run-umi-qemu.sh "$NAME" "${ARGS[@]}"
echo "run_umi_qemu exit=$?"

echo
echo "== 4. 内存几何核对（环境 / QEMU -m / ADT 三处一致）=="
python3 - "$WS/out/umi-qemu/$NAME" "$GUEST" "$OWNED" <<'PY'
import json, struct, sys
run, want_ram, want_owned = sys.argv[1], sys.argv[2], sys.argv[3]
sys.path.insert(0, "/home/unixnu/code/umi-work-pin/devices/umi/scripts")
from umi_adt import decode
adt = decode(open(f"{run}/esp/EFI/UniXNU/Payloads/kernel.macho.adt", "rb").read())
chosen = adt.at("/chosen").properties
for name in sorted(chosen):
    if any(k in name for k in ("dram", "memory")):
        raw = chosen[name]
        v = struct.unpack("<Q", raw)[0] if len(raw) == 8 else None
        print(f"  ADT /chosen/{name} = {raw.hex()}" + (f"  ({v // 1024**2} MiB)" if v else ""))
stop = json.load(open(f"{run}/gdb-stop.json"))
print("  gdb-stop qemu_memory_mib =", stop.get("qemu_memory_mib", "缺"), " 环境 GUEST =", want_ram, " OWNED =", want_owned)
PY

echo
echo "== 5. 官方 analyze_umi_data_display_qemu.py 判读（拒绝覆盖已有 analysis 档）=="
cd "$WS" || exit 1
python3 "$JUDGE" "$WS/out/umi-qemu/$NAME" > "/mnt/e/Code/HackIos/out/probes/legacy-display-analyze-$NAME.txt" 2>&1
rc=$?
echo "   analyze exit=$rc"
tail -40 "/mnt/e/Code/HackIos/out/probes/legacy-display-analyze-$NAME.txt"
python3 - "$WS/out/umi-qemu/$NAME/data-display-analysis.json" <<'PY' 2>/dev/null
import json, sys
r = json.load(open(sys.argv[1]))
m = r["metrics"]
print("\n  == 显示这一格的官方口径 ==")
print("   legacy_service_started_and_framebuffer_mapped =", r["legacy_service_started_and_framebuffer_mapped"])
print("   native_legacy_stage(判据要 10) =", m.get("native_legacy_stage"))
print("   native_legacy_start_result(判据要 1) =", m.get("native_legacy_start_result"))
print("   native_legacy_registration_calls(>0) =", m.get("native_legacy_registration_calls"))
print("   native_legacy_gop_virtual(!=0) =", m.get("native_legacy_gop_virtual"))
print("   native_legacy_guard_slot(==0) =", m.get("native_legacy_guard_slot"))
print("   actual_frame_retirement_observed =", r["actual_frame_retirement_observed"],
      "(retirement_calls =", m.get("native_legacy_retirement_calls"), ")")
print("   data_mounted_writable =", r["data_mounted_writable"],
      " actual_ram_writes_observed =", r["actual_ram_writes_observed"])
print("   launchd_main_observed =", r["launchd_main_observed"], " panic_recorded =", r["panic_recorded"],
      " critical_exit_recorded =", r["critical_exit_recorded"])
print("   status =", r["status"], " 超时停 =", r["bounded_timeout_interrupted"], " stop_pc =", r["stop_pc"])
print("   process_exit_counts =", r["process_exit_counts"])
print("   recent_process_exits =", r["recent_process_exits"])
print("   failed_process_exits =", r["failed_process_exits"])
print("   全部 native_legacy_* =", {k: v for k, v in sorted(m.items()) if k.startswith("native_legacy")})
PY
cp -f "$WS/out/umi-qemu/$NAME/screen.png" /mnt/e/Code/HackIos/out/screens/$NAME.png 2>/dev/null && \
  echo "  屏照 -> out/screens/$NAME.png"
