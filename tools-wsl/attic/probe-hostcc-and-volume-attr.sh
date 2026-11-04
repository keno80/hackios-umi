#!/bin/bash
# 两件事一次做完：
# A. 宿主件编译归因——/usr/bin/gcc 在本机 PATH（工具链在前）下报 'clang: unknown argument --64'，
#    要分清是编译器本身的问题还是 PATH 里混进了 iOS 工具链的 ld/cc1。
# B. pyfsapfs 的 volume 对象到底哪个属性是 UUID（上一发我猜 v.uuid，错）。
exec > /mnt/e/Code/HackIos/out/probes/u102-hostcc-and-volume-attr.txt 2>&1
set -u
PIN=/home/unixnu/code/umi-work-pin
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
T=$PIN/out/umi-xnu/umi/tree
export PATH="$TC/CommandLineTools/usr/bin:$TC/bin:/usr/local/bin:/usr/bin:/bin"
export LC_ALL=C CLT_PREFIX=$TC/CommandLineTools/usr XCTOOLCHAIN_PREFIX=$TC/XcodeDefault.xctoolchain/usr
export XNU_TOOLCHAIN_BIN="$TC/CommandLineTools/usr/bin $TC/XcodeDefault.xctoolchain/usr/bin"
export UNIXNU_SDKROOT=$T/.cache/fakeroot UNIXNU_SDK_VERSION=17.0
export UNIXNU_PLATFORM_PATH=$T/.cache/fakeroot/Platforms/iPhoneOS.platform

KIT=$PIN/sources/UniXNU/kits/VerifiedRoot
mkdir -p /tmp/hc && cd /tmp/hc || exit 1
printf 'int f(void){return 1;}\n' > tiny.c

echo "== A0. 谁在 PATH 前面 =="
for c in gcc cc clang ld ld64 collect2 as; do
  printf '  %-8s -> %s\n' "$c" "$(command -v $c || echo 无)"; done
echo "  /usr/bin/gcc -print-prog-name=collect2 : $(/usr/bin/gcc -print-prog-name=collect2)"
echo "  /usr/bin/gcc -print-prog-name=ld       : $(/usr/bin/gcc -print-prog-name=ld)"

echo
echo "== A1. 同一行命令，四种环境对照 =="
for label in "gcc+我们的PATH" "gcc+干净PATH" "clang+我们的PATH" "clang+干净PATH"; do
  case "$label" in
    gcc*) CC=/usr/bin/gcc ;;
    clang*) CC=/usr/bin/clang ;;
  esac
  case "$label" in
    *干净*) RUN=(env -i PATH=/usr/bin:/bin "$CC") ;;
    *) RUN=("$CC") ;;
  esac
  echo "-- $label ($CC) 编译 --"
  "${RUN[@]}" -std=c11 -Wall -Wextra -Werror -c tiny.c -o /tmp/hc/tiny.o 2>&1 | tail -3
  echo "   rc=${PIPESTATUS[0]} 产物=$(file -b /tmp/hc/tiny.o 2>/dev/null | cut -c1-60)"
  echo "-- $label ($CC) 链接共享件 --"
  env LD_LIBRARY_PATH= "${RUN[@]}" -shared -fPIC tiny.c -o /tmp/hc/tiny.so 2>&1 | tail -3
  echo "   rc=${PIPESTATUS[0]} 产物=$(file -b /tmp/hc/tiny.so 2>/dev/null | cut -c1-60)"
done

echo
echo "== A2. 真件：verified_root.c + openssl_provider.c（选 A1 里能过的组合） =="
for CC in /usr/bin/gcc /usr/bin/clang; do
  echo "-- $CC 带我们 PATH --"
  $CC -std=c11 -Wall -Wextra -Werror -shared -fPIC -I $KIT/include -I /usr/include \
     -isystem /usr/include/x86_64-linux-gnu $KIT/src/verified_root.c $KIT/tests/openssl_provider.c \
     -L /usr/lib/x86_64-linux-gnu -lcrypto -o /tmp/hc/vr-$(basename $CC).so 2>&1 | tail -6
  echo "   rc=${PIPESTATUS[0]} $(file -b /tmp/hc/vr-$(basename $CC).so 2>/dev/null | cut -c1-70)"
  echo "-- $CC 干净 PATH --"
  env -i PATH=/usr/bin:/bin $CC -std=c11 -Wall -Wextra -Werror -shared -fPIC -I $KIT/include \
     -isystem /usr/include/x86_64-linux-gnu $KIT/src/verified_root.c $KIT/tests/openssl_provider.c \
     -L /usr/lib/x86_64-linux-gnu -lcrypto -o /tmp/hc/vrc-$(basename $CC).so 2>&1 | tail -6
  echo "   rc=${PIPESTATUS[0]} $(file -b /tmp/hc/vrc-$(basename $CC).so 2>/dev/null | cut -c1-70)"
done

echo
echo "== A3. ctypes 能不能装载并跑一次 vr_host_open =="
for so in /tmp/hc/vr-gcc.so /tmp/hc/vr-clang.so /tmp/hc/vrc-gcc.so /tmp/hc/vrc-clang.so; do
  [ -f "$so" ] || continue
  python3 - "$so" <<'PY' 2>&1
import ctypes,sys
try:
    n=ctypes.CDLL(sys.argv[1])
    print(f"  {sys.argv[1]}: 装载 OK, 符号={[s for s in dir(n) if s.startswith('vr_')][:6]}")
except Exception as e:
    print(f"  {sys.argv[1]}: 装载失败 {e}")
PY
done

echo
echo "== B. pyfsapfs volume 对象的真实属性 =="
python3 - <<'PY' 2>&1
import json, subprocess
from pathlib import Path
MEDIA=Path("/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/userdata")
d=json.loads((MEDIA/"userdata-root.json").read_text())
img=Path(d["image"]); import os
if os.path.exists("/tmp/gpt-rel"): gpt_rel=int(Path("/tmp/gpt-rel").read_text())
else: gpt_rel=0x4400
import pyfsapfs
def hu(b):
    b=bytes(b)
    return "%02X%02X%02X%02X-%02X%02X-%02X%02X-%s-%s" % (b[3],b[2],b[1],b[0],b[5],b[4],b[7],b[6],
            b[8:10].hex().upper(),b[10:16].hex().upper())
for w in d["windows"]:
    rel = gpt_rel if w["name"]=="OS" else 0
    start=w["offset"]+rel; size=w["size"]-rel
    r=subprocess.run(["sudo","-n","losetup","-r","--offset",str(start),
                      "--sizelimit",str(size),"-f","--show",str(img)],
                     capture_output=True,text=True,timeout=120)
    lo=r.stdout.strip()
    print(f'-- {w["name"]} rel={hex(rel)} -> {lo} --')
    if not lo.startswith("/dev/loop"):
        print("   losetup 失败", r.stderr.strip()); continue
    try:
        c=pyfsapfs.container(); c.open(lo)
        print("   container:",[m for m in dir(c) if not m.startswith("_")])
        print("   identifier:",c.identifier, hu(c.identifier) if isinstance(c.identifier,(bytes,bytearray)) else "")
        v=c.get_volume(0)
        names=[m for m in dir(v) if not m.startswith("_")]
        print("   volume 属性:",names)
        for n in names:
            try:
                val=getattr(v,n)
            except Exception as e:
                val=f"<读不到 {e}>"; continue
            if callable(val): continue
            if isinstance(val,(bytes,bytearray)) and 0<len(val)<=32:
                print(f"     {n} = bytes {val.hex()}  mixed={hu(val)}  be={val.hex().upper()}")
            else:
                print(f"     {n} = {val!r}"[:160])
        print(f"   卷数={c.number_of_volumes}")
        for i in range(c.number_of_volumes):
            vv=c.get_volume(i)
            ident=getattr(vv,"identifier",None)
            print(f"     [{i}] name={vv.name!r} identifier={hu(ident) if isinstance(ident,(bytes,bytearray)) else ident!r}")
        c.close()
    except Exception as e:
        print("   打开失败:",type(e).__name__,e)
    finally:
        subprocess.run(["sudo","-n","losetup","-d",lo],capture_output=True)
PY
sudo -n losetup -D 2>/dev/null
echo done
