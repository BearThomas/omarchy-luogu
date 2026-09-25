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
  stdout=""
  stderr=""
  elapsed=0
  if [ "$compile_ok" = true ]; then
    timeout_s=$(( time_limit_ms / 1000 + 2 ))
    start_ns=$(date +%s%N)
    stdout=$(timeout "${timeout_s}s" sh -c "$run_cmd" < "$dir/input.txt" 2> "$dir/run.err")
    code=$?
    end_ns=$(date +%s%N)
    elapsed=$(( (end_ns - start_ns) / 1000000 ))
    stderr=$(head -c 1000 "$dir/run.err" 2>/dev/null)
    if [ "$code" -eq 124 ]; then
      status="TLE"
    elif [ "$code" -ne 0 ]; then
      status="RE"
    else
      got=$(printf '%s' "$stdout" | normalize)
      want=$(cat "$dir/expected.txt" | normalize)
      [ "$got" = "$want" ] || status="WA"
    fi
  else
    status="CE"
  fi

  jq -nc \
    --argjson index "$index" \
    --arg status "$status" \
    --argjson timeMs "$elapsed" \
    --arg stdout "$(stdout=$stdout; printf '%s' "$stdout" | head -c 4000)" \
    --arg expected "$(head -c 4000 "$dir/expected.txt")" \
    --arg stderr "$(printf '%s' "$stderr" | head -c 1000)" \
    '{index:$index, status:$status, timeMs:$timeMs, stdout:$stdout, expected:$expected, stderr:$stderr}' >> "$dir/results.jsonl"

  index=$((index + 1))
done

jq -nc \
  --argjson ok "$compile_ok" \
  --arg message "$compile_message" \
  --argjson results "$(jq -s '.' "$dir/results.jsonl")" \
  '{compile:{ok:$ok,message:$message}, results:$results}'
