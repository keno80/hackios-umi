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
# 用法：run-legacy-display-qemu.sh RUN名 [init|runtime|gate]
#   前置：run-kernel-systemos-display.sh 编完 + run-umi-prelink.sh <同一档名>
#   KNAME=prelink 基名（默认 qemu-systemos-display）
#   TIMEOUT 默认 300（gate/init）/ 900（runtime）——gate 档里它只是外层兜底，不是证据窗口
#   OWNED_MIB 默认 512；GUEST_RAM_MIB 默认 2048
#   BYPASS=1 额外挂原版 tunable panic_on_crash_disabled=1（服务退出不再拖着内核死）
#
# 三种停法的分工（TIMEOUT 不该当证据窗口，到齐就走）：
#   gate    停 _native_legacy_display_checkpoint —— 显示生命周期的**终结点**。
#           官方判据那五条（stage/start_result/registration_calls/gop_virtual/guard_slot）
#           全在 native_legacy_display_probe()/late_probe() 走到终点那一刻定形
#           （LegacyDisplayProbe.cpp:272-383：registration_observed :198、
#             gop_mapping_observed :217 都在 start() 里；checkpoint 是成功/失败两条路的收尾）。
#           所以一命中就够判 legacy_service_started_and_framebuffer_mapped，几十秒收工。
#           需要 retirement/client（真帧率、真用户件开 framebuffer）那些后面才来的面，用 runtime。
#   runtime 停 _ml_panic_trap_to_debugger（官方 runtime 停点），长窗口留给帧与进程面
#   init    停 _execve（官方 init 档）
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
  gate)    TIMEOUT=${TIMEOUT:-300}  STOPSYM=_native_legacy_display_checkpoint ;;
  *) echo "停手：STAGE 只认 init|runtime|gate，给了 $STAGE"; exit 1 ;;
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

# 两条旋钮都要的观测件（幂等；不设也是上游几何）。
# ★ 补丁件插进 runner 的是 `int(os.environ.get(...))`，取值发生在**运行 run_umi_qemu.py 那一刻**，
#   不是打补丁那一刻——所以这两个变量必须 export 给真正的执行体，只在补丁命令上赋值会让
#   GUEST_RAM_MIB 静默回落到默认 1024（u504 实测：56 档 QEMU 的 -m 就是 1024）。
export UMI_GUEST_RAM_MIB=$GUEST UMI_OWNED_MEMORY_MIB=$OWNED
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/make-run-umi-qemu-guest-ram.py > /tmp/make-run-umi-qemu-guest-ram.py
python3 /tmp/make-run-umi-qemu-guest-ram.py --runner "$WS/tools/run_umi_qemu.py" || exit 1
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/make-run-umi-qemu-chunked-read.py > /tmp/make-run-umi-qemu-chunked-read.py
python3 /tmp/make-run-umi-qemu-chunked-read.py --runner "$WS/tools/run_umi_qemu.py" || exit 1

ARGS=(--root-volume --systemos-volume --data-ramdisk "$SEED" --trust-cache "$B"
      --no-vmm-property --owned-memory-mib "$OWNED" --timeout "$TIMEOUT" --capture-screen
      --args "$BOOTARGS" --stop "$STOPSYM" --also-stop _native_legacy_backend_guard)
# 停点符号必须先验在场：run_umi_qemu.py 的 symbol() 少了就整档失败，且失败在建 run 目录之前
printf '%s\n' "$DUMP" | grep -q " ${STOPSYM}\$" || { echo "停手：停点符号 $STOPSYM 不在这份内核里"; exit 1; }
echo "  停点 $STOPSYM 在场：$(printf '%s\n' "$DUMP" | grep -m1 " ${STOPSYM}\$")"
if [ "$STAGE" != runtime ]; then
  # gate/init 只等自己的证据，panic 得当兜底，否则会白等到 TIMEOUT
  ARGS+=(--also-stop _ml_panic_trap_to_debugger)
fi
while IFS=: read -r n sz; do ARGS+=(--read-symbol "_$n:$sz"); done < /tmp/official-symbols.txt
# 官方读址集只有 26 枚显示仪表（u509 ast 实测），**帧提交面一枚都没读**：
# frame_count/copy_*/swap_*/retired_*/frame_colors* 全在内核里，但官方 runner 不挂
# → 官方 analyze 只能报 retirement_calls=0，答不了「有没有件真提交帧」。
# 尺寸唯一出处 = 判读件里的 SIZES（按 LegacyDisplayProbe.cpp 的 volatile 声明抄，u510 原文），
# 这里现取，杜绝两处手抄漂移。符号不在（比如没开 --legacy-display 的档）就跳过——
# run_umi_qemu.py 的 symbol() 缺一枚会在建 run 目录之前 error 出来。
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/evaluate-legacy-display-gate.py > /tmp/eval-legacy-display-gate.py
python3 - /tmp/eval-legacy-display-gate.py <<'PY' > /tmp/extra-meters.txt
import ast, sys
tree = ast.parse(open(sys.argv[1]).read())
for node in tree.body:
    if isinstance(node, ast.Assign) and getattr(node.targets[0], "id", "") == "SIZES":
        for name, (size, _elem) in ast.literal_eval(node.value).items():
            print(f"{name}:{size}")
PY
[ -s /tmp/extra-meters.txt ] || { echo "停手：判读件的 SIZES 取不出来（件被改了？）"; exit 1; }
OFFICIAL=" $(tr ':' ' ' < /tmp/official-symbols.txt | tr '\n' ' ') "
EXTRA_ADDED=0
while IFS=: read -r n sz; do
  printf '%s\n' "$DUMP" | grep -q " _${n}\$" || continue
  case "$OFFICIAL" in *" $n "*) continue;; esac
  ARGS+=(--read-symbol "_$n:$sz"); EXTRA_ADDED=$((EXTRA_ADDED + 1))
done < /tmp/extra-meters.txt
echo "  补挂帧提交仪表 $EXTRA_ADDED 枚（官方集之外，尺寸取判读件 SIZES）"
# checkpoint 若被早期趟先吃掉（stage 停在 1/2 而 pending 还没落地），用它跳过前 N 次命中
[ -n "${SKIP_HITS:-}" ] && ARGS+=(--skip-target-hits "$SKIP_HITS")

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
echo
echo "== 6. 本地显示五条判读件（gate 停点专用；公式与官方同式，判据不增减）=="
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/evaluate-legacy-display-gate.py > /tmp/eval-legacy-display-gate.py
python3 /tmp/eval-legacy-display-gate.py "$WS/out/umi-qemu/$NAME" --nm "$NM" \
  > "/mnt/e/Code/HackIos/out/probes/legacy-display-gate-$NAME.txt" 2>&1
echo "   evaluate exit=$?（0=五条全过）"
# 读址自检：本树 QEMU 的短读只验「非 E22」，回包 16 字符冒充 80 字节它不说话——按键与声明尺寸逐枚对
echo "-- 6b. 帧提交仪表读址自检（--check-keys）--"
python3 /tmp/eval-legacy-display-gate.py "$WS/out/umi-qemu/$NAME" --nm "$NM" --check-keys \
  > "/mnt/e/Code/HackIos/out/probes/legacy-display-keys-$NAME.txt" 2>&1
echo "   keys exit=$?（0=尺寸全对得上；非 0 见该档缺哪枚）"
grep -E '没挂读址|短读|无符号' "/mnt/e/Code/HackIos/out/probes/legacy-display-keys-$NAME.txt" | head -20
tail -30 "/mnt/e/Code/HackIos/out/probes/legacy-display-gate-$NAME.txt"
cp -f "$WS/out/umi-qemu/$NAME/screen.png" /mnt/e/Code/HackIos/out/screens/$NAME.png 2>/dev/null && \
  echo "  屏照 -> out/screens/$NAME.png"
