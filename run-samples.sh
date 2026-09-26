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
# 编译/受限运行/归一化都在 judge-lib.sh 里（对拍用的是同一份）。
set -u

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/judge-lib.sh"

IFS= read -r encoded
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT

printf '%s' "$encoded" | base64 -d > "$dir/payload.json" || {
  printf '{"compile":{"ok":false,"message":"payload 解析失败"},"results":[]}'
  exit 0
}

language=$(jq -r '.language // ""' "$dir/payload.json")
LIMIT_MS=$(jq -r '.timeLimitMs // 1000' "$dir/payload.json")
sample_count=$(jq '.samples | length' "$dir/payload.json")
jq -r '.code // ""' "$dir/payload.json" > "$dir/source.txt"

compile_program "$dir" "$language" "$dir/source.txt"
compile_ok=$COMPILE_OK
compile_message=$COMPILE_MSG
run_cmd=$PROG_RUN

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
    run_program "$run_cmd" "$dir/input.txt" "$out_file"
    elapsed=$RUN_ELAPSED
    out_bytes=$RUN_BYTES
    case "$RUN_STATUS" in
      TLE) status="TLE" ;;
      RE)
        status="RE"
        stderr=$RUN_STDERR
        ;;
      OK)
        # 只把前 64KB 读进内存比较；样例输出本来就很小
        got=$(head -c 65536 "$out_file" | normalize)
        want=$(head -c 65536 "$dir/expected.txt" | normalize)
        [ "$got" = "$want" ] || status="WA"
        ;;
    esac
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
