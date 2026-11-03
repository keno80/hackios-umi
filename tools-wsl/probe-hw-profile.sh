#!/bin/bash
cd /home/unixnu/code/umi-work-pin || exit 1
echo "=== umi-hardware.json 位置 ==="
ls -la devices/umi/package/umi-hardware.json 2>&1 | head -2
echo "--- memory_banks / gic / cpu 摘要"
python3 - <<'PY'
import json,hashlib,pathlib
p=pathlib.Path('devices/umi/package/umi-hardware.json')
if not p.is_file():
    print('MISSING'); raise SystemExit
d=json.loads(p.read_text())
print('schema',d.get('schema'),'device',d.get('device'),'soc',d.get('soc'))
print('sha256',hashlib.sha256(p.read_bytes()).hexdigest())
for b in sorted(d.get('memory_banks',[]),key=lambda x:x['base']):
    base=b['base'] if isinstance(b['base'],int) else int(b['base'],0)
    size=b['size'] if isinstance(b['size'],int) else int(b['size'],0)
    print('  bank %#x + %#x  (end %#x)'%(base,size,base+size))
tot=0
for b in d.get('memory_banks',[]):
    base=b['base'] if isinstance(b['base'],int) else int(b['base'],0)
    size=b['size'] if isinstance(b['size'],int) else int(b['size'],0)
    tot+=size
print('  sum banks = %#x (%.2f GiB)'%(tot,tot/2**30))
print('psci',d.get('psci'))
print('sources',json.dumps(d.get('sources'))[:400])
print('keys',sorted(d.keys()))
PY
echo
echo "=== 本机 running.dtb 的 /memory ==="
dtc -I dtb -O dts out/umi/dtb/umi-running.dtb 2>/dev/null | awk '/memory@/{f=1} f{print} f&&/};/{f=0}' | head -20
