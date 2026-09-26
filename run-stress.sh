#!/bin/sh
# 对拍：三份程序（我的解法 / 暴力 / 数据生成器）跑 N 轮，第一处不一致就停下，
# 并把那组数据连两份输出一起交回来。
#
# 用法：一行 base64(JSON) 从 stdin 进来，结果以 JSON 打到 stdout：
#   {"language":"C++14 (GCC 9)","solution":"...","brute":"...","generator":"...",
#    "rounds":100,"timeLimitMs":1000}
#   → {"compile":{"solution":true,"brute":true,"generator":true,"message":""},
#      "rounds":37,"status":"ok"|"mismatch"|"timeout"|"error","message":"",
#      "mismatch":{"round":37,"input":"...","solutionOut":"...","bruteOut":"...",
#                  "solutionMs":3,"bruteMs":9}}
#
# 生成器固定用 Python 3（写随机数据比 C++ 顺手，而且少一次编译）；解法和暴力用
# 插件里选的语言。全程不联网、不碰洛谷，和「本地跑样例」共用 judge-lib.sh。
set -u

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/judge-lib.sh"

IFS= read -r encoded
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT

printf '%s' "$encoded" | base64 -d > "$dir/payload.json" || {
  printf '{"compile":{"solution":false,"brute":false,"generator":false,"message":"payload 解析失败"},"status":"error","rounds":0}'
  exit 0
}

language=$(jq -r '.language // ""' "$dir/payload.json")
LIMIT_MS=$(jq -r '.timeLimitMs // 1000' "$dir/payload.json")
rounds=$(jq -r '.rounds // 100' "$dir/payload.json")
case "$rounds" in
  ''|*[!0-9]*) rounds=100 ;;
esac
[ "$rounds" -gt 1000 ] && rounds=1000
[ "$rounds" -lt 1 ] && rounds=1

jq -r '.solution // ""' "$dir/payload.json" > "$dir/solution.txt"
jq -r '.brute // ""' "$dir/payload.json" > "$dir/brute.txt"
jq -r '.generator // ""' "$dir/payload.json" > "$dir/generator.txt"

compile_program "$dir/sol" "$language" "$dir/solution.txt"
solution_ok=$COMPILE_OK
solution_msg=$COMPILE_MSG
solution_run=$PROG_RUN

compile_program "$dir/brute" "$language" "$dir/brute.txt"
brute_ok=$COMPILE_OK
brute_msg=$COMPILE_MSG
brute_run=$PROG_RUN

# 生成器固定 Python 3：program_spec 认 "Python" 就给 python3 + 不编译
compile_program "$dir/gen" "Python 3" "$dir/generator.txt"
generator_ok=$COMPILE_OK
generator_run=$PROG_RUN

if [ "$solution_ok" != true ] || [ "$brute_ok" != true ] || [ "$generator_ok" != true ]; then
  message=""
  [ "$solution_ok" = true ] || message="解法编译失败：$solution_msg"
  if [ "$brute_ok" != true ]; then
    [ -n "$message" ] && message="$message
"
    message="$message暴力编译失败：$brute_msg"
  fi
  if [ "$generator_ok" != true ]; then
    [ -n "$message" ] && message="$message
"
    message="$message生成器（Python）失败：$generator_msg"
  fi
  jq -nc \
    --argjson solution "$solution_ok" \
    --argjson brute "$brute_ok" \
    --argjson generator "$generator_ok" \
    --arg message "$message" \
    '{compile:{solution:$solution, brute:$brute, generator:$generator, message:$message}, rounds:0, status:"error", message:$message}'
  exit 0
fi

# 总时长兜底：数据生成器写歪了（比如生成了 10^7 个数）不能让面板一直转。
deadline=$(( $(date +%s) + 60 ))

status="ok"
message=""
mismatch_json="null"
generated=0
round=1
while [ "$round" -le "$rounds" ]; do
  # 生成数据：生成器不该读输入，给 /dev/null
  run_program "$generator_run" /dev/null "$dir/gen.out"
  if [ "$RUN_CODE" -ne 0 ]; then
    status="error"
    message="数据生成器第 $round 轮运行失败（$RUN_STATUS）"
    break
  fi
  # 输入太大就截断：两份程序都得能在时限内跑完，否则测的是输出量不是正确性
  head -c 100000 "$dir/gen.out" > "$dir/input.txt"

  run_program "$solution_run" "$dir/input.txt" "$dir/sol.out"
  sol_code=$RUN_CODE
  sol_status=$RUN_STATUS
  sol_ms=$RUN_ELAPSED
  sol_text=$(head -c 4000 "$dir/sol.out" 2>/dev/null | tr -d '\000')

  run_program "$brute_run" "$dir/input.txt" "$dir/brute.out"
  brute_code=$RUN_CODE
  brute_ms=$RUN_ELAPSED
  brute_text=$(head -c 4000 "$dir/brute.out" 2>/dev/null | tr -d '\000')

  reason=""
  if [ "$sol_code" -ne 0 ]; then
    reason="解法在这组数据上 $sol_status"
  elif [ "$brute_code" -ne 0 ]; then
    reason="暴力在这组数据上 $RUN_STATUS（暴力本身写错了？）"
  else
    got=$(head -c 65536 "$dir/sol.out" | normalize)
    want=$(head -c 65536 "$dir/brute.out" | normalize)
    [ "$got" = "$want" ] || reason="两份程序输出不同"
  fi

  if [ -n "$reason" ]; then
    status="mismatch"
    message="第 $round 轮发现问题：$reason"
    mismatch_json=$(jq -nc \
      --argjson round "$round" \
      --arg reason "$reason" \
      --arg input "$(head -c 4000 "$dir/input.txt" | tr -d '\000')" \
      --arg solutionOut "$sol_text" \
      --arg bruteOut "$brute_text" \
      --argjson solutionMs "$sol_ms" \
      --argjson bruteMs "$brute_ms" \
      '{round:$round, reason:$reason, input:$input, solutionOut:$solutionOut, bruteOut:$bruteOut, solutionMs:$solutionMs, bruteMs:$bruteMs}')
    generated=$round
    break
  fi

  generated=$round
  if [ "$(date +%s)" -ge "$deadline" ]; then
    status="timeout"
    message="跑满 60 秒（完成 $round 轮），没发现分歧"
    break
  fi
  round=$((round + 1))
done

[ "$status" = "ok" ] && message="$generated 轮全部一致"

jq -nc \
  --arg status "$status" \
  --arg message "$message" \
  --argjson rounds "$generated" \
  --argjson mismatch "$mismatch_json" \
  '{compile:{solution:true, brute:true, generator:true, message:""}, rounds:$rounds, status:$status, message:$message, mismatch:$mismatch}'
