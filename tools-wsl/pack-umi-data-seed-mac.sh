#!/bin/bash
# U 步之七之八之二：把 Mac 侧 make-owner-data-seed-mac.sh 产出的 raw APFS 容器打成内核吃的 Data 种子
# 用法：pack-umi-data-seed-mac.sh <mac 产出的 .cdr> [--name data-mac]
#   只做 Linux 侧本来就会的那三步：packed_ramdisk.pack() → 身份 .json（inspect 的键 + Mac 回读的 volume_uuid）→ 按 build 侧闸自检。
#   volume_uuid 从随行的 seed.json 里取（与 .cdr 同目录），没有就停手——UUID 是编译期钉进内核头的，不能猜。
set -u
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export LC_ALL=C
WS=/home/unixnu/code/umi-work-pin
DS=$WS/devices/umi/package/data-store
CDR=${1:-}
[ $# -gt 0 ] && shift || true
NAME=data-mac
while [ $# -gt 0 ]; do
  case "$1" in
    --name) NAME=$2; shift 2 ;;
    *) echo "停手：不认识参数 $1"; exit 1 ;;
  esac
done

[ -n "$CDR" ] || { echo "用法：pack-umi-data-seed-mac.sh <mac 产出的 .cdr> [--name 基名]"; exit 1; }
[ -f "$CDR" ] || { echo "停手：找不到 $CDR"; exit 1; }
[ -f "$DS/packed_ramdisk.py" ] || { echo "停手：缺 $DS/packed_ramdisk.py"; exit 1; }
SEEDJSON="$(dirname "$CDR")/seed.json"
[ -f "$SEEDJSON" ] || { echo "停手：缺随行的 $SEEDJSON（Mac 脚本产的身份件，volume_uuid 从这儿来）"; exit 1; }

OUTD=$WS/out/umi/data-seed
mkdir -p "$OUTD"
RAW=$OUTD/$NAME.raw
DBR=$OUTD/$NAME.dbr
JSON=$OUTD/$NAME.json
rm -f "$RAW" "$DBR" "$JSON"

echo "== 0. Mac 侧回读的身份 =="
cat "$SEEDJSON"
BYTES=$(stat -c %s "$CDR")
MAGIC=$(dd if="$CDR" bs=1 skip=32 count=4 2>/dev/null)
echo "  大小=$BYTES  块 0+0x20=$MAGIC"
[ "$MAGIC" = "NXSB" ] || { echo "停手：这不是 raw APFS 容器"; exit 1; }
# 留一份同名 .raw，方便和 mkapfs 那条路共用同一套判读脚本
cp "$CDR" "$RAW"

echo
echo "== 1. packed_ramdisk.pack() + 写身份 .json =="
python3 - "$CDR" "$DBR" "$JSON" "$DS/packed_ramdisk.py" "$SEEDJSON" <<'PY'
import importlib.util, json, pathlib, sys
cdr, dbr, js = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3])
spec = importlib.util.spec_from_file_location('pr', sys.argv[4]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
mac = json.loads(pathlib.Path(sys.argv[5]).read_text())
uuid = mac.get('volume_uuid') or mac.get('VolumeUUID')
if not uuid:
    raise SystemExit('停手：seed.json 里没有 volume_uuid')
m.pack(cdr, dbr)
meta, header = m.inspect(dbr)
identity = dict(meta)
identity['volume_uuid'] = uuid.upper()
js.write_text(json.dumps(identity, indent=2, sort_keys=True) + '\n')
print('  原始', cdr.stat().st_size, 'B -> 编码', dbr.stat().st_size, 'B')
print('  header[32:36] =', header[32:36])
print('  .json =', json.dumps(identity, sort_keys=True))
PY

echo
echo "== 2. 自检：按 build 侧闸（build_umi_xnu.py:92-95/:150）的三条判据 =="
python3 - "$DBR" "$JSON" "$DS/packed_ramdisk.py" "$CDR" <<'PY'
import hashlib, importlib.util, json, pathlib, sys
dbr, js, cdr = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[4])
spec = importlib.util.spec_from_file_location('pr', sys.argv[3]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
identity = json.loads(js.read_text())
actual, header = m.inspect(dbr)
fails = []
if not actual.get('packed'): fails.append('packed 不为真')
if header[32:36] != b'NXSB': fails.append(f'逻辑块 +32 不是 NXSB（{header[32:36]!r}）')
if any(actual.get(k) != identity.get(k) for k in actual): fails.append('.json 与 inspect 不一致')
if not identity.get('volume_uuid'): fails.append('.json 缺 volume_uuid')
print('  对照键：', {k: actual[k] for k in actual}, '| volume_uuid =', identity.get('volume_uuid'))
print('  种子 sha256 =', hashlib.sha256(cdr.read_bytes()).hexdigest())
print('  自检', 'PASS' if not fails else 'FAIL: ' + '; '.join(fails))
sys.exit(1 if fails else 0)
PY
rc=$?

echo
echo "块件：$DBR"
echo "身份：$JSON"
echo "下一步：把 \$JSON 里的 volume_uuid 交给 run-kernel-systemos-data.sh（重编 Data 档内核），"
echo "        QEMU 用 --data-ramdisk $DBR，判据是 _native_owner_data_status 从 2 变 0、stage=4。"
[ $rc = 0 ] && echo "pack-umi-data-seed-mac OK" || echo "pack-umi-data-seed-mac FAIL"
exit $rc
