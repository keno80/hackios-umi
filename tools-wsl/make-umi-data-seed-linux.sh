#!/bin/bash
# U 步之七之三：Linux 侧造一份 DBRDISK1 打包的 APFS Data 种子（全程不碰 Mac）
# 用法：make-umi-data-seed-linux.sh [logical MiB，默认 512]
#   实测依据（out/probes/u233、u234）：
#     mkapfs 在 /usr/sbin（apfsprogs 0+git20231203），128 MiB 起才能造（16/64 MiB 报 small containers are not supported）
#     packed_ramdisk.pack() 纯 Python：256 MiB 空卷 -> 编码 73,840 B，inspect() 给 5 键
#     build 侧闸（tools/build_umi_xnu.py:92-95）：packed=True 且 header[32:36]==NXSB 且 .json 与 inspect 逐键相等，
#       并要 .json 里有 volume_uuid（:150 把它钉成 XNU_OWNER_DATA_VOLUME_UUID）
#   注意 mkapfs 的 -U 是**容器** UUID、-u 是**卷** UUID（fsapfsinfo 两段 Identifier 分开回读），
#     内核按卷 UUID 找种子，所以卷 UUID 才是 data.json 里的 volume_uuid。
set -u
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export LC_ALL=C
WS=/home/unixnu/code/umi-work-pin
DS=$WS/devices/umi/package/data-store
SIZE_MIB=${1:-512}
OUTD=$WS/out/umi/data-seed
NAME=data-$SIZE_MIB
RAW=$OUTD/$NAME.raw
DBR=$OUTD/$NAME.dbr
JSON=$OUTD/$NAME.json
CONTAINER_UUID=${CONTAINER_UUID:-2f8a4b1c-6d3e-4a7f-9c52-0b1e7d8f4a63}
VOLUME_UUID=${VOLUME_UUID:-7c1e9d42-58b6-4f0a-9d31-6a2e5b7c8f10}

[ -x /usr/sbin/mkapfs ] || { echo "停手：缺 /usr/sbin/mkapfs（apfsprogs 没装）"; exit 1; }
[ -f "$DS/packed_ramdisk.py" ] || { echo "停手：缺 $DS/packed_ramdisk.py"; exit 1; }
mkdir -p "$OUTD"
rm -f "$RAW" "$DBR" "$JSON"

echo "== 1. mkapfs 造裸容器（logical=${SIZE_MIB}MiB）=="
truncate -s "$((SIZE_MIB * 1024 * 1024))" "$RAW"
out=$(/usr/sbin/mkapfs -L Data -U "$CONTAINER_UUID" -u "$VOLUME_UUID" "$RAW" 2>&1); rc=$?
echo "  mkapfs rc=$rc ${out:0:140}"
[ "$rc" = 0 ] || { echo "停手：造卷失败"; exit 1; }
echo "  --- fsapfsinfo 回读（容器/卷两段 Identifier 必须是钉的那两个）---"
fsapfsinfo "$RAW" 2>&1 | sed 's/^/  /'

echo
echo "== 2. packed_ramdisk.pack() 打包 + 写身份 .json =="
python3 - "$RAW" "$DBR" "$JSON" "$DS/packed_ramdisk.py" "$VOLUME_UUID" <<'PY'
import importlib.util, json, pathlib, sys
raw, dbr, js = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3])
spec = importlib.util.spec_from_file_location('pr', sys.argv[4]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
m.pack(raw, dbr)
meta, header = m.inspect(dbr)
identity = dict(meta)
identity['volume_uuid'] = sys.argv[5]
js.write_text(json.dumps(identity, indent=2, sort_keys=True) + '\n')
print('  原始', raw.stat().st_size, 'B -> 编码', dbr.stat().st_size, 'B')
print('  header[:8] =', header[:8], ' header[32:36] =', header[32:36])
print('  .json =', json.dumps(identity, sort_keys=True))
PY

echo
echo "== 3. 自检：按 build 侧闸的三条判据（不重编就能先判契约是否满足）=="
python3 - "$DBR" "$JSON" "$DS/packed_ramdisk.py" <<'PY'
import hashlib, importlib.util, json, pathlib, struct, sys
dbr, js = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
spec = importlib.util.spec_from_file_location('pr', sys.argv[3]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
identity = json.loads(js.read_text())
actual, header = m.inspect(dbr)
fails = []
if not actual.get('packed'): fails.append('packed 不为真')
if header[32:36] != b'NXSB': fails.append(f'逻辑块 +32 不是 NXSB（{header[32:36]!r}）')
if any(actual.get(k) != identity.get(k) for k in actual): fails.append('.json 与 inspect 不一致')
if not identity.get('volume_uuid'): fails.append('.json 缺 volume_uuid')
if not actual['bytes'] % 4096: pass
print('  对照键：', {k: actual[k] for k in actual}, '| volume_uuid =', identity.get('volume_uuid'))
print('  identity_sha256 =', hashlib.sha256(js.read_bytes()).hexdigest())
print('  自检', 'PASS' if not fails else 'FAIL: ' + '; '.join(fails))
sys.exit(1 if fails else 0)
PY
rc=$?
echo
echo "种子：$DBR"
echo "身份：$JSON"
[ $rc = 0 ] && echo "make-umi-data-seed-linux OK" || echo "make-umi-data-seed-linux FAIL"
exit $rc
