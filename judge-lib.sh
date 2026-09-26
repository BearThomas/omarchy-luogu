#!/bin/sh
# 本地评测的公共部分：语言映射、编译、受限运行、输出归一化。
#
# 被 run-samples.sh（跑题目样例）和 run-stress.sh（对拍）source。
# 抽出来的理由很实际：这一份里全是踩过坑的地方（输出不能进 shell 变量、ulimit -f
# 兜底、Java 的类名、fpc 的 -o 写法），复制第二份迟早两边跑偏。
#
# 约定：所有结果通过全局变量回传（POSIX sh 没有比这更干净的写法）。

# 语言 → 源文件名后缀 / 编译命令 / 运行命令。
#   $1 = 程序目录（不同程序各占一个目录，Java 的 Main 类才不会撞名）
#   $2 = 语言名（来自洛谷的语言列表）
# 产出：PROG_SUFFIX / PROG_COMPILE / PROG_RUN
program_spec() {
  case "$2" in
    *Python*|*PyPy*)
      PROG_SUFFIX=".py"
      PROG_COMPILE=""
      PROG_RUN="python3 $1/main.py"
      ;;
    *Java*)
      PROG_SUFFIX=".java"
      PROG_COMPILE="javac -d $1 $1/Main.java"
      PROG_RUN="java -cp $1 Main"
      ;;
    *Node*|*JavaScript*)
      PROG_SUFFIX=".js"
      PROG_COMPILE=""
      PROG_RUN="node $1/main.js"
      ;;
    *Rust*)
      PROG_SUFFIX=".rs"
      PROG_COMPILE="rustc -O -o $1/prog $1/main.rs"
      PROG_RUN="$1/prog"
      ;;
    *Go*)
      PROG_SUFFIX=".go"
      PROG_COMPILE="go build -o $1/prog $1/main.go"
      PROG_RUN="$1/prog"
      ;;
    *Pascal*)
      PROG_SUFFIX=".pas"
      PROG_COMPILE="fpc -O2 -o$1/prog $1/main.pas"
      PROG_RUN="$1/prog"
      ;;
    "C")
      PROG_SUFFIX=".c"
      PROG_COMPILE="gcc -O2 -std=c11 -o $1/prog $1/main.c"
      PROG_RUN="$1/prog"
      ;;
    *)
      PROG_SUFFIX=".cpp"
      PROG_COMPILE="g++ -O2 -std=c++14 -o $1/prog $1/main.cpp"
      PROG_RUN="$1/prog"
      ;;
  esac
  # 源码就放在程序目录下的 main<后缀>
  PROG_SOURCE="$1/main$PROG_SUFFIX"
  export PROG_SUFFIX PROG_COMPILE PROG_RUN PROG_SOURCE
}

# 把源码写进程序目录并编译。
#   $1 = 程序目录, $2 = 语言名, $3 = 源码文件
# 产出：COMPILE_OK / COMPILE_MSG / PROG_RUN
compile_program() {
  _cp_dir="$1"
  mkdir -p "$_cp_dir"
  program_spec "$_cp_dir" "$2"
  cp "$3" "$PROG_SOURCE"
  COMPILE_OK=true
  COMPILE_MSG=""
  if [ -n "$PROG_COMPILE" ]; then
    if ! sh -c "$PROG_COMPILE" > "$_cp_dir/compile.out" 2> "$_cp_dir/compile.err"; then
      COMPILE_OK=false
      COMPILE_MSG=$(head -c 2000 "$_cp_dir/compile.err" 2>/dev/null)
    fi
  fi
  export COMPILE_OK COMPILE_MSG PROG_RUN
}

# 行尾空白与末尾空行不算差别（评测机也是这么比的）
normalize() {
  awk '{ sub(/\r$/, ""); sub(/[ \t]+$/, ""); print }' | awk '
    { if ($0 == "") { blank++; next } while (blank > 0) { print ""; blank-- } print }
  '
}

# 在时限和文件大小双保险下跑一个程序。
#   $1 = 运行命令, $2 = 输入文件, $3 = 输出文件（stderr 落在 $3.err）
# 产出：RUN_CODE / RUN_ELAPSED（毫秒）/ RUN_BYTES / RUN_STDERR
#
# 两条不能动的规矩：
#  1. **输出的去向永远是文件，绝不用 $(...) 捕获。** 时限管不住输出量，一个疯狂
#     打印的程序能在几秒内吃掉大量内存（实测旧版跑 putchar 死循环：程序 3 秒被
#     杀，但之后还要在几百 MB 的捕获变量上做 normalize，整轮 12.9 秒）。
#  2. 用 ulimit -f 给文件大小兜底：8192 × 512B = 4MB，超了程序被 SIGXFSZ 杀掉。
run_program() {
  _rp_cmd="$1"
  _rp_in="$2"
  _rp_out="$3"
  _rp_err="$3.err"
  _rp_timeout=$(( LIMIT_MS / 1000 + 2 ))
  : > "$_rp_out"
  _rp_start=$(date +%s%N)
  # 用一个真正 fork 出来的 sh 跑：程序被 SIGXFSZ/SIGFPE 等信号杀掉时，父 shell 会
  # 额外打一行作业通知（"File size limit exceeded"），而 `( )` 对单条命令不一定
  # 真 fork，所以通知会从脚本自己的 stderr 冒出去、盖掉插件的提示文案。
  sh -c 'timeout "$1s" sh -c "ulimit -f 8192 2>/dev/null; exec $2" < "$3" > "$4" 2> "$5"' \
    sh "$_rp_timeout" "$_rp_cmd" "$_rp_in" "$_rp_out" "$_rp_err" 2> "$_rp_err.shell"
  RUN_CODE=$?
  _rp_end=$(date +%s%N)
  RUN_ELAPSED=$(( (_rp_end - _rp_start) / 1000000 ))
  RUN_STDERR=$(head -c 1000 "$_rp_err" 2>/dev/null)
  RUN_BYTES=$(wc -c < "$_rp_out" 2>/dev/null | tr -d ' ')
  [ -n "$RUN_BYTES" ] || RUN_BYTES=0
  case "$RUN_CODE" in
    124) RUN_STATUS="TLE" ;;
    153) RUN_STATUS="RE"; RUN_STDERR="输出过大：超过 4MB 上限，已被终止" ;;
    0)   RUN_STATUS="OK" ;;
    *)   RUN_STATUS="RE" ;;
  esac
  # 撞到上限不一定死于 SIGXFSZ：解释器（python 就是）会把 write 失败变成 OSError，
  # 退出码不是 153，用户只会看到一句 traceback。输出顶到上限就统一给这句话。
  if [ "$RUN_CODE" -ne 0 ] && [ "$RUN_BYTES" -ge 4194304 ]; then
    RUN_STATUS="RE"
    RUN_STDERR="输出过大：超过 4MB 上限，已被终止"
  fi
  export RUN_CODE RUN_ELAPSED RUN_BYTES RUN_STDERR RUN_STATUS
}
