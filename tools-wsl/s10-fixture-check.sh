#!/bin/bash
# S 步静态验收：件里必须真多出 4 发负号 svc、_walk/_nz 各扩到 40 quad、上游判据偏移没动。
# 不验就跑去烧 QEMU 一轮，等于把 3 分钟的事换成 30 分钟。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s10-fixture-check.txt 2>&1
source /usr/local/bin/unixnu-env 2>/dev/null
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
CLT=$TC/CommandLineTools/usr
IMG=/mnt/e/Code/HackIos/out/fixtures/launchd-walk.macho

echo "== 1. 身份 =="
ls -la "$IMG"; sha256sum "$IMG"

echo
echo "== 2. S 步标记串（出图闸要用）=="
S=$(strings -a "$IMG" | grep -c -F 'UMI-WALK-S-VM-PAYLOAD')
Q=$(strings -a "$IMG" | grep -c -F 'UMI-WALK-Q-PIPE-PAYLOAD')
echo "S标记=$S Q标记=$Q"

echo
echo "== 3. 符号地址：_walk/_nz 间距应为 40*8=320(0x140) =="
"$CLT/bin/nm" -n "$IMG" | grep -E '_results|_user_page_size|_old_length|_walk|_nz|_checkpoint|_start'
WA=$("$CLT/bin/nm" -n "$IMG" | awk '/ _walk$/{print $1}')
NA=$("$CLT/bin/nm" -n "$IMG" | awk '/ _nz$/{print $1}')
echo "walk=0x$WA nz=0x$NA"
python3 - "$WA" "$NA" <<'PY'
import sys
w,n=int(sys.argv[1],16),int(sys.argv[2],16)
print("间距 =", n-w, "字节 ->", "40 quad OK" if n-w==320 else "不对（期望 320）")
PY

echo
echo "== 4. 上游判据偏移必须仍是 4000/4028/4030 =="
"$CLT/bin/nm" -n "$IMG" | grep -E '_results|_user_page_size|_old_length' | \
  awk '{print $3"="$1}' | grep -E '0x?100004000|100004028|100004030' | wc -l
echo "（上面应为 3）"

echo
echo "== 5. 反汇编数 svc 与负号（应 39 发；新增 -10 -14 -21 -12）=="
SECT=$("$CLT/bin/otool" -l "$IMG" | grep -A6 sectname | tr -d ' ')
ADDR=$(OT="$CLT/bin/otool" IM="$IMG" python3 - <<'PY'
import subprocess,re,os
o=subprocess.run([os.environ["OT"], "-l", os.environ["IM"]],capture_output=True,text=True).stdout
m=re.search(r'sectname __text.*?addr (0x[0-9a-f]+).*?size (0x[0-9a-f]+).*?offset (\d+)',o,re.S)
print(m.group(1),m.group(2),m.group(3))
PY
)
set -- $ADDR
A=$1 SZ=$2 OFF=$3
echo "ADDR=$A SIZE=$SZ OFF=$OFF"
W=/tmp/fx-s10; rm -rf $W; mkdir -p $W
SZD=$((SZ))
dd if="$IMG" of=$W/text.bin bs=1 skip=$OFF count=$SZD status=none
# 必须用交叉版 objdump：PATH 里那份在这个工具链环境下不认 aarch64
# （s11 实测报 "can't use supplied machine aarch64"，静默出 0 发 svc）。
/usr/bin/aarch64-linux-gnu-objdump -D -b binary -m aarch64 --adjust-vma=$A $W/text.bin > $W/text.asm 2>&1
N=$(grep -c 'svc' $W/text.asm)
echo "svc 发数=$N（R 版是 35，S 版应 39）"
echo "--- 全部写 x16 的负号（objdump 把负数放在行尾注释里，只能按 '#-N' 抓）："
grep 'x16' $W/text.asm | grep -oE '#-[0-9]+' | sort -V | uniq -c
echo "--- 末尾 24 条指令（S 段应在这里）："
grep -E '^\s+[0-9a-f]+:' $W/text.asm | tail -24
echo "== done $(date -u +%FT%TZ)"
