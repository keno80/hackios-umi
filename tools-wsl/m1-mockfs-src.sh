set -u
exec >>/mnt/e/Code/HackIos/out/probes/m1-mockfs-src.txt 2>&1
W=/home/unixnu/code/umi-work-pin
echo "== 0. 定位 =="
find $W/out/umi-xnu/umi/tree/.cache/xnu-work -name 'mockfs*' 2>/dev/null
find /home/unixnu/code/UniXNU-main/scripts /home/unixnu/code/UniXNU-umi -maxdepth 3 -name 'build-native-user-fixture.py' -o -maxdepth 3 -name 'build-target-dyld-fixture.py' 2>/dev/null
echo
echo "== 1. mockfs_fsnode.h =="
F=$(find $W/out/umi-xnu/umi/tree/.cache/xnu-work -name mockfs_fsnode.h 2>/dev/null | head -1)
echo "-- $F"
cat -n "$F"
echo
echo "== 2. mockfs_vfsops.c 校验与挂载段 =="
V=$(find $W/out/umi-xnu/umi/tree/.cache/xnu-work -name mockfs_vfsops.c 2>/dev/null | head -1)
echo "-- $V  (total $(wc -l <"$V") lines)"
sed -n '1,200p' "$V" | cat -n
echo
echo "== 3. mockfs_vnops.c lookup =="
N=$(find $W/out/umi-xnu/umi/tree/.cache/xnu-work -name mockfs_vnops.c 2>/dev/null | head -1)
echo "-- $N  (total $(wc -l <"$N") lines)"
sed -n '60,200p' "$N" | cat -n
echo "== done =="
