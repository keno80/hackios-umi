#!/bin/bash
cd /home/unixnu/code/umi-work-pin || exit 1
echo "=== 谁生成 qemu esp 载荷 ==="
grep -rln "make-umi-adt\|kernel.macho.adt\|DarwinBoot.efi" tools/ devices/umi/tools/ devices/umi/bringup/ /mnt/e/Code/HackIos/tools-wsl/ 2>/dev/null | head -20
echo
echo "=== run-06-root 目录里非 esp 的文件 ==="
ls out/umi-qemu/run-06-root/ | head -20
echo
echo "=== ADT 生成命令记录（provenance 里的 adt 命令）==="
grep -o '"command":.*' out/umi-qemu/run-06-root/provenance.json | head -3
python3 - <<'PY'
import json,glob
for p in glob.glob('/home/unixnu/code/umi-work-pin/out/umi-qemu/run-06-root/*.json'):
    try: d=json.load(open(p))
    except Exception: continue
    s=json.dumps(d)
    if 'adt' in s.lower():
        print('---',p)
        for k,v in (d.items() if isinstance(d,dict) else []):
            if 'adt' in k.lower() or 'args' in k.lower() or 'kernel' in k.lower():
                print(' ',k,'=',str(v)[:200])
PY
echo
echo "=== 我们 QEMU 侧 adt 的生成脚本 ==="
ls out/umi-qemu/run-06-root/*.py 2>/dev/null | head -10
