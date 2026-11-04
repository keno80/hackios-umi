#!/bin/bash
# Task #9 follow-up: cross-check the captured umi layout against the addresses
# our UEFI/kernel path hard-codes. Read-only over local capture files.
set -u
OUT=${1:-}
ROOT_DIR=/home/unixnu/code/umi-work-pin
if [ -z "$OUT" ]; then
  OUT=$(ls -1d "$ROOT_DIR"/out/device/umi/* 2>/dev/null | tail -1)
fi
LOG=/mnt/e/Code/HackIos/out/probes/check-phone-layout.txt
exec >"$LOG" 2>&1
echo "capture: $OUT"
[ -d "$OUT" ] || { echo "no capture directory"; exit 1; }

echo; echo "=== report completeness"
python3 - "$OUT" <<'PY'
import json,sys
from pathlib import Path
r=json.loads((Path(sys.argv[1])/'report.json').read_text())
print('identity:', {k:r['identity'][k] for k in ('ro.product.device','ro.board.platform','ro.soc.model','ro.build.version.release','ro.lineage.version','ro.boot.slot_suffix') if k in r['identity']})
print('root_identity:', r.get('root_identity'))
print('required_collection_complete:', r.get('required_collection_complete'))
bad=[k for k,v in r['reads'].items() if 'error' in v or v.get('exit_code',0)!=0]
print('reads failed/partial:', bad or 'none')
art={k:('ERROR: '+v['error']) if 'error' in v else f"{v.get('bytes')}B sha256={str(v.get('sha256'))[:16]}.. verified={v.get('device_sha256_verified')}" for k,v in r['artifacts'].items()}
for k,v in art.items(): print(' artifact', k, v)
for d,g in r['gpt'].items():
    print(' gpt', d, ('ERROR: '+g['error']) if 'error' in g else f"{len(g['partitions'])} partitions, sector={g['logical_block_bytes']}")
PY

echo; echo "=== hardcoded windows vs /proc/iomem"
for a in 0x9c000000 0x9fc00000 0xa0000000 0xb0000000 0x80000000; do
  echo "-- $a"
  grep -i -n "$(printf '%s' "$a" | sed 's/^0x//;s/$/-/')" "$OUT/iomem.txt" 2>/dev/null | head -5
done
echo "-- whole RAM region / reserved"
grep -i -n -E 'System RAM|Reserved|Persistent RAM|pstore|ramoops|kgsl|memremap' "$OUT/iomem.txt" 2>/dev/null | head -40

echo; echo "=== /proc/cmdline"
cat "$OUT/cmdline.txt" 2>/dev/null
echo; echo "=== /proc/bootconfig"
head -40 "$OUT/bootconfig.txt" 2>/dev/null

echo; echo "=== memory node of running dtb"
if command -v dtc >/dev/null 2>&1 && [ -s "$OUT/running.dtb" ]; then
  dtc -I dtb -O dts "$OUT/running.dtb" 2>/dev/null | grep -n -A3 -E '^\s+(memory@|reserved-memory|ramoops|phandle = <0x[0-9a-f]+>)' | head -60
  dtc -I dtb -O dts "$OUT/running.dtb" 2>/dev/null | sed -n '/reserved-memory/,/^\t};/p' | head -60
else
  echo "dtc missing or dtb empty (dtc: apt-get install device-tree-compiler)"
fi

echo; echo "=== dmesg memory/panic-region lines"
grep -i -E 'Memory:|reserved|ramoops|panic|efi|initrd|Linux version' "$OUT/dmesg.txt" 2>/dev/null | head -30

echo; echo "=== by-name links of interest"
grep -E ' (boot|recovery|dtbo|vbmeta|userdata|metadata|super|xbl|abl|imagefv|init_boot|vendor_boot)(_[ab])? ->' "$OUT/partition-links.txt" 2>/dev/null | head -40

echo; echo "=== userdata size"
python3 - "$OUT" <<'PY'
import json,sys
from pathlib import Path
r=json.loads((Path(sys.argv[1])/'report.json').read_text())
for disk,g in r.get('gpt',{}).items():
    for p in g.get('partitions',[]):
        if p['name'] in ('userdata','metadata','super') or 'userdata' in p['name']:
            print(disk,p['name'],f"{p['size_bytes']:,}B", 'off', f"{p['offset_bytes']:,}")
PY

echo; echo "=== screen/display/input"
cat "$OUT/display-size.txt" 2>/dev/null
head -4 "$OUT/display-connector.txt" 2>/dev/null
cat "$OUT/touch-driver.txt" 2>/dev/null
head -20 "$OUT/input-devices.txt" 2>/dev/null
echo; echo "DONE"
