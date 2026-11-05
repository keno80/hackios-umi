#!/bin/bash
# U 步之九之一：产 display-reference.macho —— 官方 legacy-display 档唯一缺的输入件。
#
# 为什么它能本机产（三条实测，见 out/probes/u488.txt / u489.txt）：
#   1) build_umi_prelink.py:79-81 写死了 `if status["legacy_display"]: roots += 三枚显示根`
#      → display-reference 不是什么外部下载件，就是一枚带这三枚根的 prelink 候选件；
#   2) 供体 out/umi-xnu/ipsw/21H461/kernelcache.decompressed 的 sha256 = f18b4df8…，
#      与 devices/umi/board.toml 的 kernelcache_sha256 逐字节相同（build_umi_prelink.py:67 的同一把尺子）；
#   3) 供体里 IOMobileGraphicsFamily 出现 20 次、IOSurface 3 次、IOGPUFamily 18 次，而现有 mac64
#      候选件的 extents 里显示模块 0 枚 —— 差别只在 --root 要不要。
# 本件不修改上游任何工具：命令按 board.toml [kernel.prelink] 拼，只是把三枚显示根显式加上，
# 并另写一份 .note.json 说明「它是从没开 legacy_display 的源内核产的」（判下游绑定址时要用）。
#
# 用法：run-display-reference.sh [输出名，默认 display-reference]
#   FORCE=1 把已存在的同名件改名保留后再产
set -u
NAME=${1:-display-reference}
WS=/home/unixnu/code/umi-work-pin
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
export PATH="$TC/CommandLineTools/usr/bin:$TC/bin:/usr/local/bin:/usr/bin:/bin"
export LC_ALL=C
export XNU_TOOLCHAIN_BIN="$TC/CommandLineTools/usr/bin $TC/XcodeDefault.xctoolchain/usr/bin"
cd "$WS" || exit 1

KERNEL=out/umi-xnu/umi/kernel/qemu-prelink-source-kernel.macho
STATUS=out/umi-xnu/umi/qemu-prelink-source-build-status.json
DONOR=out/umi-xnu/ipsw/21H461/kernelcache.decompressed
OUT=out/umi-xnu/umi/kernel/$NAME.macho

for f in "$KERNEL" "$STATUS" "$DONOR"; do
  [ -f "$f" ] || { echo "★缺前置件 $f"; exit 1; }
done
if [ -e "$OUT" ]; then
  if [ "${FORCE:-0}" = 1 ]; then
    mv "$OUT" "$OUT.stale-$(date +%Y%m%d-%H%M%S)"
    mv "$OUT.json" "$OUT.json.stale-$(date +%Y%m%d-%H%M%S)" 2>/dev/null
  else
    echo "$OUT 已存在（emit_prelink 拒绝覆盖）；要重来就 FORCE=1 run-display-reference.sh $NAME"; exit 1
  fi
fi

echo "== 1. 自检：供体 sha 对 board.toml 钉值、源内核对 status 记值 =="
python3 - <<'PY'
import hashlib, json, pathlib, tomllib
donor = pathlib.Path("out/umi-xnu/ipsw/21H461/kernelcache.research.umi")
donor = pathlib.Path("out/umi-xnu/ipsw/21H461/kernelcache.decompressed")
board = tomllib.loads(pathlib.Path("devices/umi/board.toml").read_text())["kernel"]["prelink"]
status = json.loads(pathlib.Path("out/umi-xnu/umi/qemu-prelink-source-build-status.json").read_text())
kernel = pathlib.Path(status["kernel"])
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
print(f"   board.slide={board['slide']}  early_security_init={board['early_security_init']}")
print(f"   board.roots（{len(board['roots'])} 枚）= " + " / ".join(board["roots"]))
print(f"   源内核 {kernel.name} sha={sha(kernel)[:16]}…  status.sha256={status['sha256'][:16]}…  "
      f"{'MATCH' if sha(kernel)==status['sha256'] else '★不符'}")
print(f"   供体 sha={sha(donor)[:16]}…  board.kernelcache_sha256={board['kernelcache_sha256'][:16]}…  "
      f"{'MATCH' if sha(donor)==board['kernelcache_sha256'] else '★不符'}")
print(f"   status 面：legacy_display={status.get('legacy_display')} data_ramdisk={'有' if status.get('data_ramdisk') else '无'} "
      f"systemos={status.get('systemos')} screen_diagnostics={status.get('screen_diagnostics')}")
assert sha(donor) == board["kernelcache_sha256"], "供体与 board.toml 钉值不符"
assert sha(kernel) == status["sha256"], "源内核与构建记录不符"
PY

echo
echo "== 2. 拼命令并跑 emit_prelink（上游件一字未改，只多给三枚显示根）=="
python3 - <<'PY' > /tmp/display-roots.txt
import tomllib, pathlib
board = tomllib.loads(pathlib.Path("devices/umi/board.toml").read_text())["kernel"]["prelink"]
roots = list(board["roots"])
roots += ["com.apple.filesystems.apfs", "com.apple.AppleFSCompression.AppleFSCompressionTypeZlib"]
roots += ["com.apple.iokit.IOMobileGraphicsFamily", "com.apple.iokit.IOSurface", "com.apple.iokit.IOGPUFamily"]
print(" ".join(roots))
PY
read -r ROOTS < /tmp/display-roots.txt
STATUS_KERNEL=$(python3 -c "import json;print(json.load(open('out/umi-xnu/umi/qemu-prelink-source-build-status.json'))['kernel'])")
BOARD_SLIDE=$(python3 -c "import tomllib;print(tomllib.load(open('devices/umi/board.toml','rb'))['kernel']['prelink']['slide'])")
BOARD_TOOL=$(python3 -c "import tomllib;print(tomllib.load(open('devices/umi/board.toml','rb'))['kernel']['prelink']['tool'])")
BOARD_ESI=$(python3 -c "import tomllib;print(tomllib.load(open('devices/umi/board.toml','rb'))['kernel']['prelink']['early_security_init'])")

CMD=(python3 -u "sources/UniXNU/$BOARD_TOOL" --kernel "$STATUS_KERNEL" --prelinked out/umi-xnu/ipsw/21H461/kernelcache.decompressed
     "--slide=$BOARD_SLIDE" --output "$OUT" "--early-security-init=$BOARD_ESI")
for r in $ROOTS; do CMD+=("--root" "$r"); done
echo "   ${CMD[*]}"
LOG=/home/unixnu/code/UniXNU-main/out/unixnu-logs/display-reference-$(date +%H%M%S).log
"${CMD[@]}" > "$LOG" 2>&1
rc=$?
echo "   emit_prelink exit=$rc  日志 $LOG"
[ $rc -eq 0 ] || { tail -25 "$LOG"; exit $rc; }

echo
echo "== 3. 产出的候选件是否真带三枚显示根、family 可执行体是否逐字节等于官方钉值 =="
python3 - "out/umi-xnu/umi/kernel/$NAME.macho" <<'PY'
import hashlib
import json
import pathlib
import sys

FAMILY = "com.apple.iokit.IOMobileGraphicsFamily"
FAMILY_TEXT_SHA = "2e044ee68c1650397e1435234ca6459206262e4c7ed709cb7131c6f664f9bd9b"
sys.path.insert(0, "sources/UniXNU/kits/NativePrelink")
from native_prelink import macho, backed_offset

p = pathlib.Path(sys.argv[1])
plan = json.loads(p.with_suffix(".json").read_text())
blob = p.read_bytes()
sha = lambda b: hashlib.sha256(b).hexdigest()
mods = sorted({e["module"] for e in plan.get("extents", [])})
print(f"   {p.name}  {len(blob)} B  candidate_sha256={plan['candidate_sha256'][:16]}…  "
      f"{'自洽' if plan['candidate_sha256'] == sha(blob) else '★不自洽'}")
print(f"   original_sha256={plan['original_sha256'][:16]}…  "
      f"{'==display() 第 73 行的钉值 ✓' if plan['original_sha256'] == 'f18b4df865405f2a287b84977d7aca745e056d656d9fc9df1662970ce2969de7' else '★不符'}")
print(f"   extents 模块 {len(mods)} 枚；显示相关 = {[m for m in mods if any(t in m for t in ('Graphics', 'Surface', 'GPU'))]}")
oes = plan.get("original_executable_sha256", {})
print(f"   original_executable_sha256 键数={len(oes)}；family 记值 = {str(oes.get(FAMILY))[:20]}…")
text = next((e for e in plan["extents"] if e["module"] == FAMILY and e["segment"] == "__TEXT_EXEC"), None)
if text is None:
    print("   ★extents 里没有 family 的 __TEXT_EXEC —— 官方 audit 第 173 行会 StopIteration")
else:
    image = macho(blob)
    at = backed_offset(image["segments"], text["va"], text["size"], len(blob))
    got = sha(blob[at:at + text["size"]])
    print(f"   family __TEXT_EXEC va={hex(text['va'])} size={text['size']}  实读 sha={got[:16]}…")
    print(f"   官方 audit 第 166/174 行的判据：{'PASS（逐字节等于钉值）' if got == FAMILY_TEXT_SHA == oes.get(FAMILY) else '★FAIL'}")
PY

echo
echo "== 4. 记一份来路说明（免得下游把它的绑定址当成开过 display 的那版内核）=="
python3 - "out/umi-xnu/umi/kernel/$NAME" <<'PY'
import hashlib
import json
import pathlib
import sys
import tomllib

stem = pathlib.Path(sys.argv[1])
board = tomllib.loads(pathlib.Path("devices/umi/board.toml").read_text())["kernel"]["prelink"]
status = json.loads(pathlib.Path("out/umi-xnu/umi/qemu-prelink-source-build-status.json").read_text())
note = {
    "role": "legacy-display 档的参照候选件（官方 display() 第 70-73 行的输入）",
    "produced_by": "tools-wsl/run-display-reference.sh",
    "tool": "sources/UniXNU/" + board["tool"] + "（上游件一字未改）",
    "tool_sha256": hashlib.sha256(pathlib.Path("sources/UniXNU/" + board["tool"]).read_bytes()).hexdigest(),
    "kernel_input": status["kernel"],
    "kernel_input_sha256": status["sha256"],
    "kernel_input_legacy_display": bool(status.get("legacy_display")),
    "donor": "out/umi-xnu/ipsw/21H461/kernelcache.decompressed",
    "donor_sha256": board["kernelcache_sha256"],
    "roots_requested": board["roots"] + ["com.apple.filesystems.apfs",
                                        "com.apple.AppleFSCompression.AppleFSCompressionTypeZlib",
                                        "com.apple.iokit.IOMobileGraphicsFamily",
                                        "com.apple.iokit.IOSurface",
                                        "com.apple.iokit.IOGPUFamily"],
    "caveat": "源内核是没开 --legacy-display 的那版；产出的绑定址属于该版布局。开 display 重编后要用新源内核再产一次，"
              "并把这份 note 的 kernel_input_sha256 换成新版，否则 provider 绑到旧址。",
    "candidate_sha256": json.loads(stem.with_suffix(".json").read_text())["candidate_sha256"],
}
stem.with_suffix(".note.json").write_text(json.dumps(note, indent=2, ensure_ascii=False) + "\n")
print("   " + str(stem.with_suffix(".note.json")))
print(json.dumps(note, indent=2, ensure_ascii=False)[:1200])
PY

echo
echo "== 5. 下一步（本件不做，留给判过闸之后再 kick）=="
echo "   run-kernel-systemos-display.sh —— 在 mac64 档之上加 --legacy-display（它硬要求 systemos+screen-diagnostics）"
echo
echo "== run-display-reference 结束 =="
