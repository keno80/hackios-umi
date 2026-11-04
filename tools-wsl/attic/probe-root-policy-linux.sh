#!/bin/bash
# U 步之三备料取证：root-policy 这条子链在 Linux 上到底缺哪几件。
# A. Linux 侧能不能读出 OS/SystemOS 窗的真实 APFS 卷 UUID（prepare_umi_root_policy.py 要它）
# B. VerifiedRoot/tests/check.py 的 Mac 假设在 Linux 上的等价物（openssl 前缀、-dynamiclib）
exec > /mnt/e/Code/HackIos/out/probes/u93-root-policy-linux-feasibility.txt 2>&1
set -u
PIN=/home/unixnu/code/umi-work-pin
MEDIA=$PIN/out/umi-xnu/umi/userdata

echo "== A0. userdata 实况 + 各窗字节 =="
ls -la $MEDIA 2>&1
python3 - <<'PY'
import json
d=json.loads(open("/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/userdata/userdata-root.json").read())
print("image:",d["image"])
for w in d["windows"]:
    print(f'  {w["name"]:9s} offset={w["offset"]} size={w["size"]} ({w["size"]/2**30:.2f} GiB) sha={w["sha256"][:16]}')
PY

echo
echo "== A0b. 磁盘空间（决定用 losetup 还是 carve） =="
df -h /home/unixnu /mnt/e /mnt/d /tmp 2>&1 | grep -v tmpfs
echo "  sudo 免密：$(sudo -n true 2>&1 && echo 可用 || echo 不可用)"
command -v losetup >/dev/null && echo "  losetup 有" || echo "  losetup 无"

echo
echo "== A1. Linux APFS 工具是否可用 =="
for c in fsapfsinfo fsapkmp apfsck mountapfs.blktag; do
  printf '  %-18s %s\n' "$c" "$(command -v $c || echo 无)"
done
python3 -c "import pyfsapfs; print('  pyfsapfs 可导入 OK'); print('  container 方法:',[m for m in dir(pyfsapfs.container()) if not m.startswith('_')])" 2>&1 | tail -4

echo
echo "== A2. 拿到 OS 窗的只读视图（优先 losetup，退路 carve） =="
VIEW=""
LODEV=""
python3 - > /tmp/oswin.env <<'PY'
import json
from pathlib import Path
MEDIA=Path("/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/userdata")
d=json.loads((MEDIA/"userdata-root.json").read_text())
w=[x for x in d["windows"] if x["name"]=="OS"][0]
print(f'IMG={d["image"]}\nOFF={w["offset"]}\nLEN={w["size"]}')
PY
cat /tmp/oswin.env
. /tmp/oswin.env
if command -v losetup >/dev/null && sudo -n true 2>/dev/null; then
  LODEV=$(sudo -n losetup -r --offset "$OFF" --sizelimit "$LEN" -f --show "$IMG" 2>&1)
  echo "  losetup rc=$? -> $LODEV"
  [ -b "$LODEV" ] && VIEW="$LODEV"
else
  echo "  跳过 losetup（无 sudo 或无命令）"
fi
if [ -z "$VIEW" ]; then
  mkdir -p /mnt/e/Code/HackIos/out/scratch
  echo "  用 dd bs=4M carve 到 /mnt/e/Code/HackIos/out/scratch/os-carve.img（约 5.7 GiB，需要几分钟）"
  time dd if="$IMG" of=/mnt/e/Code/HackIos/out/scratch/os-carve.img \
       bs=4M skip="$OFF" count="$LEN" iflag=skip_bytes,count_bytes status=none
  VIEW=/mnt/e/Code/HackIos/out/scratch/os-carve.img
fi
echo "  VIEW=$VIEW"

echo
echo "== A3. 视图上的 APFS 超级块位置 =="
python3 - "$VIEW" <<'PY' 2>&1
import sys
from pathlib import Path
p=Path(sys.argv[1])
for off in (0, 0x10000, 0x104420, 0x200000):
    try:
        with p.open("rb") as f:
            f.seek(off); b=f.read(8)
        print(f"  magic@{hex(off)}: {b}")
    except Exception as e:
        print(f"  magic@{hex(off)}: 读失败 {e}")
PY

echo
echo "== A4. fsapfsinfo 直读（容器 UUID / 卷 UUID） =="
if command -v fsapfsinfo >/dev/null; then
  fsapfsinfo -p 0 "$VIEW" 2>&1 | head -60
else
  echo "  fsapfsinfo 不在，试 pyfsapfs"
fi

echo
echo "== A5. pyfsapfs 读容器与各卷 UUID（mixed-endian 解码） =="
python3 - "$VIEW" <<'PY' 2>&1
import sys
try:
    import pyfsapfs
except Exception as e:
    print("  pyfsapfs 不可用:",e); raise SystemExit
def hu(b):
    b=bytes(b)
    if len(b)!=16: return b.hex()
    return "%02X%02X%02X%02X-%02X%02X-%02X%02X-%s-%s" % (
        b[3],b[2],b[1],b[0],b[5],b[4],b[7],b[6],b[8:10].hex().upper(),b[10:16].hex().upper())
cont=pyfsapfs.container()
try:
    cont.open(sys.argv[1])
except Exception as e:
    print("  open 失败:",type(e).__name__,e); raise SystemExit
print("  容器 nx_uuid:",hu(cont.uuid))
print("  卷数:",cont.number_of_volumes)
for i in range(cont.number_of_volumes):
    v=cont.get_volume(i)
    extra=[]
    for a in ("flags","is_read_only","number_of_snapshots","created_in_kernel_boot_uuid"):
        if hasattr(v,a): extra.append(f"{a}={getattr(v,a)}")
    print(f"  [{i}] name={v.name!r} uuid={hu(v.uuid)} {' '.join(extra)}")
PY

echo
echo "== A6. run_umi_qemu.py 侧怎么读 UUID（对照判据） =="
grep -n -i "uuid\|volume_info\|root-match" $PIN/tools/run_umi_qemu.py 2>&1 | head -40
echo "  -- 上游有没有现成的 Linux 卷信息产法 --"
grep -rn "volume-info.json" $PIN/tools/*.py 2>&1 | head -20

echo
echo "== B1. VerifiedRoot check.py 全文 =="
cat $PIN/sources/UniXNU/kits/VerifiedRoot/tests/check.py 2>&1

echo
echo "== B2. openssl 3 在 Linux 侧的位置 =="
printf '  /usr/include/openssl/opensslv.h %s\n' "$([ -e /usr/include/openssl/opensslv.h ] && echo 有 || echo 缺)"
pkg-config --modversion openssl 2>&1 | sed 's/^/  pkg-config openssl: /'
ls /usr/lib/x86_64-linux-gnu/libcrypto.* 2>&1 | head -5
openssl version 2>&1

echo
echo "== B3. check.py 在 Linux 上直接试跑，看第一个报错点 =="
cd $PIN/sources/UniXNU/kits/VerifiedRoot 2>/dev/null || echo "  目录不存在"
timeout 240 python3 tests/check.py --output /tmp/vr-host --openssl-prefix /usr 2>&1 | tail -40
echo "  退出码=${PIPESTATUS[0]}"

echo
echo "== B4. /tmp/vr-host 产物 =="
ls -la /tmp/vr-host 2>&1 | head -25
if [ -n "$LODEV" ] && [ -b "$LODEV" ]; then echo; echo "== 收尾：释放 loop =="; sudo -n losetup -d "$LODEV" 2>&1; fi
echo done
