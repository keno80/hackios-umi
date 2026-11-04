set -u
exec >>/mnt/e/Code/HackIos/out/probes/m3-inputs.txt 2>&1
U=/home/unixnu/code/UniXNU-main
echo "== 1. native-user.S 全文 =="
wc -l $U/scripts/qemu-entry/native-user.S
cat -n $U/scripts/qemu-entry/native-user.S
echo
echo "== 2. fixture 是怎么在 Linux 上产出来的（有没有 xcrun shim）=="
which xcrun codesign vtool 2>/dev/null
ls -la /usr/local/bin/ | grep -i -E "xcrun|codesign|vtool|ld" 
echo "-- launchd.macho 的 Mach-O 头与签名 load command"
od -An -tx1 -N16 $U/build/native-user-fixture-umi/launchd.macho
echo
echo "== 3. 上游参考件现状 =="
ls -la $U/refer/ 2>/dev/null | head -30
echo "-- UniXNU-umi/refer"
ls -la /home/unixnu/code/UniXNU-umi/refer/ 2>/dev/null | head -30
echo "-- target-volumes"
ls -la $U/.cache/firmware/target-volumes/ 2>/dev/null
ls -la $U/.cache/firmware/target-volumes/os-mount/sbin/ 2>/dev/null | head
echo "-- 全盘找 ipsw / os-mount / static-trustcache（只读，限时）"
timeout 60 find /home/unixnu -maxdepth 6 \( -iname '*.ipsw' -o -name 'static-trustcache.bin' -o -name 'os-mount' \) 2>/dev/null | head -20
echo "== done =="
