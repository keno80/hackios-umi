#!/bin/bash
# U 步之四：在 Linux 上产出官方原件 trust bundle（out/umi/trustcache/original-static-system.bundle）。
# 只做两件事：取 BuildManifest.plist（唯一缺的输入），然后原样跑官方 tools/prepare_umi_trustcache.py。
# 不自己拼 bundle——bundle 的 sha 由官方件里的 assert 钉死成 7416ca4f…，改不动也不该改。
set -u
WS=/home/unixnu/code/umi-work-pin
LOG=/mnt/e/Code/HackIos/out/probes/original-trust-linux.txt
exec > >(tee "$LOG") 2>&1

source /usr/local/bin/unixnu-env || exit 1
cd "$WS" || exit 1

BUNDLE=$WS/out/umi/trustcache/original-static-system.bundle
WANT=7416ca4f8377146626bb284e2133c76bee6cb4e3ee0af5d648b186235a7323a7

echo "== 1. 输入核对：board.toml 的 [ipsw].fetch 四件是否都在本地 =="
for f in 044-76040-038.dmg.trustcache 044-76034-038.dmg.trustcache DeviceTree.j120ap.im4p kernelcache.decompressed; do
  p=$WS/out/umi-xnu/ipsw/21H461/$f
  [ -f "$p" ] && sha256sum "$p" || echo "!! 缺 $p"
done

echo
echo "== 2. 取 BuildManifest.plist（HTTP range，只读它一个成员）=="
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/fetch-ipsw-buildmanifest-linux.py > /tmp/fbm.py
python3 /tmp/fbm.py
echo "fetch exit=$?"

echo
echo "== 3. 跑官方 prepare_umi_trustcache.py（一字未改）=="
python3 tools/prepare_umi_trustcache.py
echo "prepare exit=$?"

echo
echo "== 4. 产物与 sha（必须等于 $WANT）=="
[ -f "$BUNDLE" ] && sha256sum "$BUNDLE"
[ -f "$BUNDLE" ] && [ "$(sha256sum "$BUNDLE" | cut -d' ' -f1)" = "$WANT" ] \
  && echo "BUNDLE-OK" || echo "BUNDLE-MISMATCH"
echo "-- inputs.json --"
[ -f "$WS/out/umi/trustcache/inputs.json" ] && cat "$WS/out/umi/trustcache/inputs.json"
