set -u
exec >>/mnt/e/Code/HackIos/out/probes/m4-fixture-rebuild.txt 2>&1
U=/home/unixnu/code/UniXNU-main
echo "== 1. xcrun shim 是什么 =="
file /usr/bin/xcrun /usr/bin/codesign
sed -n '1,60p' /usr/bin/xcrun
echo
echo "== 2. 现有 fixture 指纹 =="
sha256sum $U/build/native-user-fixture-umi/launchd.macho $U/build/native-user-fixture-umi/launchd-static.macho $U/build/native-user-fixture-umi/user.o
echo
echo "== 3. 试在 Linux 重建（写到 /tmp/fx-rebuild，不覆盖原件）=="
cd $U || exit 1
timeout 300 python3 scripts/build-native-user-fixture.py --output /tmp/fx-rebuild 2>&1 | tail -30
echo "rebuild rc=$?"
echo
echo "== 4. 重建产物指纹与对比 =="
ls -la /tmp/fx-rebuild/ 2>/dev/null
if [ -f /tmp/fx-rebuild/launchd.macho ]; then
  A=$(sha256sum $U/build/native-user-fixture-umi/launchd.macho | cut -c1-64)
  B=$(sha256sum /tmp/fx-rebuild/launchd.macho | cut -c1-64)
  echo "orig=$A"
  echo "new =$B"
  echo "REBUILD $([ "$A" = "$B" ] && echo IDENTICAL || echo DIFFERENT)"
fi
echo "== done =="
