set -u
exec >>/mnt/e/Code/HackIos/out/probes/m7-syscall-table.txt 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
M=$X/bsd/kern/syscalls.master
echo "== 0. 文件 =="
wc -l $M
echo
echo "== 1. 名单内的 unix syscall 号 =="
for n in exit fork read write open close wait4 getpid getppid kill mmap munmap unlink stat fstat lstat access brk getuid setuid pipe dup2 dup select nanosleep usleep readlink getdirentries; do
  grep -E "^[[:space:]]*[0-9]+[[:space:]]\|.*\b$n\b" $M | head -2 | sed "s/^/  /"
done
echo
echo "== 2. 直接按第一个字段取号（AUE 行）=="
grep -E "^[[:space:]]*(1|2|3|4|5|6|7|20|23|37|39|41|55|57|73|74|96|97|100|101|116|117|122|135|153|171|202|227|319|338|341)[[:space:]]" $M | head -45
echo
echo "== 3. 我们的 EL0 探针打印的到底是什么 =="
grep -n -A14 'EL0 UNIX svc' /home/unixnu/code/UniXNU-umi/patches/umi-xnu/zzzzzzzzzzzzzzzzzzzzzz-umi-el0-probe.patch | head -40
echo
echo "== 4. sleh.c 里 unix syscall 号怎么算出来的 =="
grep -n "code & \|SC_AST\|unix_syscall\|MAXSYSCALL\|num = " $X/osfmk/arm64/sleh.c | head -30
echo "== done =="
