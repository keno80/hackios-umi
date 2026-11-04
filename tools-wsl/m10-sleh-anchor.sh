set -u
exec >>/mnt/e/Code/HackIos/out/probes/m10-sleh-anchor.txt 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
echo "== 1. 现有 22z 探针补丁全文 =="
cat /home/unixnu/code/UniXNU-umi/patches/umi-xnu/zzzzzzzzzzzzzzzzzzzzzz-umi-el0-probe.patch
echo
echo "== 2. sleh.c 里 handle_svc 的 unix 分派段（1930-2010）=="
sed -n '1930,2010p' $X/osfmk/arm64/sleh.c | cat -n | sed 's/^/  /'
echo
echo "== 3. trap_no 从哪来 =="
grep -n "trap_no" $X/osfmk/arm64/sleh.c | head -20
echo
echo "== 4. carry 存取 API =="
grep -rn "get_saved_state_carry_state\|set_saved_state_carry_state" $X/osfmk/arm64/ | head -8
echo
echo "== 5. unix syscall 号上限 =="
grep -rn "MAXSYSCALL\|SYS_maxunixsyscall\|code & 0x3ff\|& 0x3ff" $X/osfmk/arm64/sleh.c $X/bsd/kern/bsd_init.c 2>/dev/null | head -10
echo "== done =="
