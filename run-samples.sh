#!/bin/sh
# 本地跑样例：编译（如果需要）+ 用每个样例的输入运行 + 与期望输出比对。
#
# 用法：把一行 base64(JSON) 从 stdin 传进来，结果以 JSON 打到 stdout：
#   {"language":"C++14 (GCC 9)","code":"...","timeLimitMs":1000,
#    "samples":[{"input":"1 2\n","output":"3\n"}]}
#   → {"compile":{"ok":true,"message":""},
#      "results":[{"index":1,"status":"AC","timeMs":3,"stdout":"3\n","expected":"3\n","stderr":""}]}
#
# 全程不联网、不碰洛谷：只是把代码写进临时目录、本地编译运行。
set -u

IFS= read -r encoded
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT

printf '%s' "$encoded" | base64 -d > "$dir/payload.json" || {
  printf '{"compile":{"ok":false,"message":"payload 解析失败"},"results":[]}'
  exit 0
}

language=$(jq -r '.language // ""' "$dir/payload.json")
time_limit_ms=$(jq -r '.timeLimitMs // 1000' "$dir/payload.json")
jq -r '.code // ""' "$dir/payload.json" > "$dir/source.txt"
sample_count=$(jq '.samples | length' "$dir/payload.json")

# 语言 → 源文件名、编译命令、运行命令
compile_cmd=""
run_cmd=""
case "$language" in
  *Python*|*PyPy*)          cp "$dir/source.txt" "$dir/main.py";  run_cmd="python3 $dir/main.py" ;;
  *Java*)                   cp "$dir/source.txt" "$dir/Main.java"; compile_cmd="javac -d $dir $dir/Main.java"; run_cmd="java -cp $dir Main" ;;
  *Node*|*JavaScript*)      cp "$dir/source.txt" "$dir/main.js";  run_cmd="node $dir/main.js" ;;
  *Rust*)                   cp "$dir/source.txt" "$dir/main.rs";  compile_cmd="rustc -O -o $dir/prog $dir/main.rs"; run_cmd="$dir/prog" ;;
  *Go*)                     cp "$dir/source.txt" "$dir/main.go";  compile_cmd="go build -o $dir/prog $dir/main.go"; run_cmd="$dir/prog" ;;
  *Pascal*)                 cp "$dir/source.txt" "$dir/main.pas"; compile_cmd="fpc -O2 -o$dir/prog $dir/main.pas"; run_cmd="$dir/prog" ;;
  "C")                      cp "$dir/source.txt" "$dir/main.c";   compile_cmd="gcc -O2 -std=c11 -o $dir/prog $dir/main.c"; run_cmd="$dir/prog" ;;
  *)                        cp "$dir/source.txt" "$dir/main.cpp"; compile_cmd="g++ -O2 -std=c++14 -o $dir/prog $dir/main.cpp"; run_cmd="$dir/prog" ;;
esac

compile_ok=true
compile_message=""
if [ -n "$compile_cmd" ]; then
  if ! sh -c "$compile_cmd" > "$dir/compile.out" 2> "$dir/compile.err"; then
    compile_ok=false
    compile_message=$(head -c 2000 "$dir/compile.err" 2>/dev/null)
  fi
fi

# 行尾空白与末尾空行不算差别（评测机也是这么比的）
normalize() {
  awk '{ sub(/\r$/, ""); sub(/[ \t]+$/, ""); print }' | awk '
    { if ($0 == "") { blank++; next } while (blank > 0) { print ""; blank-- } print }
  '
}

: > "$dir/results.jsonl"
index=1
while [ "$index" -le "$sample_count" ]; do
  jq -r ".samples[$((index - 1))].input // \"\"" "$dir/payload.json" > "$dir/input.txt"
  jq -r ".samples[$((index - 1))].output // \"\"" "$dir/payload.json" > "$dir/expected.txt"

  status="AC"
  stderr=""
  elapsed=0
  out_bytes=0
  out_file="$dir/run.out"
  : > "$out_file"
  if [ "$compile_ok" = true ]; then
    timeout_s=$(( time_limit_ms / 1000 + 2 ))
    # 程序的输出直接落文件，**绝不用 $(...) 捕获**：时限管不住输出量，一个疯狂
    # 打印的程序能在几秒内吃掉大量内存（实测旧版跑 putchar 死循环：程序 3 秒被
    # 杀，但之后还要在几百 MB 的捕获变量上做 normalize，整轮 12.9 秒）。
    # ulimit -f 再给文件大小兜底：8192 × 512B = 4MB，超了程序会被 SIGXFSZ 杀掉。
    start_ns=$(date +%s%N)
    # 用一个真正 fork 出来的 sh 跑：程序被 SIGXFSZ/SIGFPE 等信号杀掉时，父 shell 会
    # 额外打一行作业通知（"File size limit exceeded"），而 `( )` 对单条命令不一定
    # 真 fork，所以通知会从脚本自己的 stderr 冒出去、盖掉插件的提示文案。
    sh -c 'timeout "$1s" sh -c "ulimit -f 8192 2>/dev/null; exec $2" < "$3" > "$4" 2> "$5"' \
      sh "$timeout_s" "$run_cmd" "$dir/input.txt" "$out_file" "$dir/run.err" 2> "$dir/run.err.shell"
    code=$?
    end_ns=$(date +%s%N)
    elapsed=$(( (end_ns - start_ns) / 1000000 ))
    stderr=$(head -c 1000 "$dir/run.err" 2>/dev/null)
    out_bytes=$(wc -c < "$out_file" | tr -d ' ')
    if [ "$code" -eq 124 ]; then
      status="TLE"
    elif [ "$code" -eq 153 ]; then
      # 153 = 128 + SIGXFSZ：撞上了 ulimit -f
      status="RE"
      stderr="输出过大：超过 4MB 上限，已被终止"
    elif [ "$code" -ne 0 ]; then
      status="RE"
    else
      # 只把前 64KB 读进内存比较；样例输出本来就很小
      got=$(head -c 65536 "$out_file" | normalize)
      want=$(head -c 65536 "$dir/expected.txt" | normalize)
      [ "$got" = "$want" ] || status="WA"
    fi
  else
    status="CE"
  fi

  jq -nc \
    --argjson index "$index" \
    --arg status "$status" \
    --argjson timeMs "$elapsed" \
    --argjson stdoutBytes "$out_bytes" \
    --arg stdout "$(head -c 4000 "$out_file" 2>/dev/null | tr -d '\000')" \
    --arg expected "$(head -c 4000 "$dir/expected.txt")" \
    --arg stderr "$(printf '%s' "$stderr" | head -c 1000)" \
    '{index:$index, status:$status, timeMs:$timeMs, stdoutBytes:$stdoutBytes, stdout:$stdout, expected:$expected, stderr:$stderr}' >> "$dir/results.jsonl"

  index=$((index + 1))
done

jq -nc \
  --argjson ok "$compile_ok" \
  --arg message "$compile_message" \
  --argjson results "$(jq -s '.' "$dir/results.jsonl")" \
  '{compile:{ok:$ok,message:$message}, results:$results}'
