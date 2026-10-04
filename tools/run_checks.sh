#!/bin/sh
# INKWAVE Godot：本地资源与规则的统一验证入口。
#
# 依次执行：
#   1. 素材导入（仅在 assets/ 比上次戳记更新时）
#   2. 解析预检（失败立即停止）
#   3. 本地资源完整性门（失败立即停止）
#   4. 其余无界面规则短测
#
# 用法：
#   tools/run_checks.sh
#   GODOT=/path/to/godot tools/run_checks.sh
#
# 退出码非 0 表示有任一步骤失败。判定一个短测通过的条件是：退出码为 0、
# 输出有单独的 PASS: 行，且日志中没有脚本/解析错误。
#
# 规范要求“声明已移植必须附可重现用例与结果”，本脚本就是那个可重现入口。
set -u

HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

INKWAVE_PROJECT_DIR="$HERE"
. "$HERE/tools/lib/runtime.sh"
inkwave_find_godot || exit $?

printf 'Godot: %s\n\n' "$("$GODOT" --version 2>/dev/null | tail -1)"

inkwave_import_assets || exit $?

failed=0
passed=0

# --- 2. 解析预检与短测辅助 ---------------------------------------------------------------
# The macOS sandbox cannot query system CA certificates; this exact engine
# diagnostic is unrelated to the local scene checks. Other ERROR lines fail.
NOISE='^ERROR: Condition "ret != noErr" is true\. Returning: ""$'
CHECK_TIMEOUT="${CHECK_TIMEOUT:-120}"
case "$CHECK_TIMEOUT" in
  ''|*[!0-9]*|0) printf '%s\n' 'CHECK_TIMEOUT 必须为正整数秒。' >&2; exit 2 ;;
esac

# Runs a command with a wall-clock limit. A check that raises a script error can
# leave the SceneTree alive forever instead of reaching quit(), which hangs the
# whole suite with no output; a timeout turns that into a visible FAIL.
run_limited() {
  "$@" &
  limited_pid=$!
  limited_waited=0
  while kill -0 "$limited_pid" 2>/dev/null; do
    if [ "$limited_waited" -ge "$CHECK_TIMEOUT" ]; then
      kill -9 "$limited_pid" 2>/dev/null
      wait "$limited_pid" 2>/dev/null
      return 124
    fi
    sleep 1
    limited_waited=$((limited_waited + 1))
  done
  wait "$limited_pid"
}

run_check() {
  path=$1
  name=$(basename "$path" .gd)
  log="$HERE/.godot/$name.log"
  run_limited "$GODOT" --headless --log-file "$HERE/.godot/$name.engine.log" --path "$HERE" --script "res://${path#"$HERE/"}" >"$log" 2>&1
  status=$?
  problems=$(grep -E '^ERROR:|^SCRIPT ERROR:|^Parse Error:|^FAIL:|Invalid call|Failed to load|Cannot call method' "$log" | grep -vE "$NOISE" | head -3)
  if [ "$status" -eq 0 ] && grep -q '^PASS:' "$log" && [ -z "$problems" ]; then
    printf 'PASS  %s\n' "$name"
    passed=$((passed + 1))
    return 0
  else
    if [ "$status" -eq 124 ]; then
      printf 'FAIL  %s (exceeded %ss and was killed)\n' "$name" "$CHECK_TIMEOUT"
    else
      printf 'FAIL  %s (exit=%s)\n' "$name" "$status"
    fi
    grep -E '^ERROR:|^FAIL:|^SCRIPT ERROR:|^Parse Error:|Invalid call|Failed to load|Cannot call method' "$log" | head -4 | sed 's/^/      /'
    if [ -n "$problems" ]; then
      printf '%s\n' "$problems" | sed 's/^/      /'
    elif ! grep -q '^PASS:' "$log"; then
      tail -4 "$log" | sed 's/^/      /'
    fi
    failed=$((failed + 1))
    return 1
  fi
}

# Run this explicitly first: glob order otherwise starts dependent scene checks
# before the parse gate. A failed gate must never launch the remaining scenes.
if ! run_check "$HERE/tests/godot/check_scripts_parse.gd"; then
  printf '\n解析预检失败，停止后续规则短测。通过 %d，失败 %d\n' "$passed" "$failed"
  printf '日志保留在 %s/*.log\n' "$HERE/.godot"
  exit 1
fi

# --- 3. 本地资源完整性门 -------------------------------------------------------
if ! run_check "$HERE/tests/godot/check_asset_integrity.gd"; then
  printf '\n资源完整性失败，停止后续规则短测。通过 %d，失败 %d\n' "$passed" "$failed"
  exit 1
fi

# --- 4. 规则短测
for path in "$HERE"/tests/godot/check_*.gd; do
  case "$(basename "$path")" in check_scripts_parse.gd|check_asset_integrity.gd) continue ;; esac
  run_check "$path"
done

printf '\n%s\n' "----------------------------------------"
printf '通过 %d，失败 %d\n' "$passed" "$failed"
if [ "$failed" -ne 0 ]; then
  printf '日志保留在 %s/*.log\n' "$HERE/.godot"
  exit 1
fi
printf '全部通过。\n'
