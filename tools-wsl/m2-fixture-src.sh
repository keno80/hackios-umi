set -u
exec >>/mnt/e/Code/HackIos/out/probes/m2-fixture-src.txt 2>&1
S=/home/unixnu/code/UniXNU-main/scripts
B=/home/unixnu/code/UniXNU-main/build/native-user-fixture-umi
echo "== 0. fixture 相关源与产物 =="
ls -la $B 2>/dev/null
find /home/unixnu/code/UniXNU-main -maxdepth 3 -iname '*native-user*' 2>/dev/null
find /home/unixnu/code/UniXNU-main -maxdepth 4 -iname '*fixture*.c' 2>/dev/null | head -20
echo
echo "== 1. build-native-user-fixture.py 全文 =="
cat -n $S/build-native-user-fixture.py
echo
echo "== 2. build-target-dyld-fixture.py 全文 =="
cat -n $S/build-target-dyld-fixture.py
echo "== done =="
