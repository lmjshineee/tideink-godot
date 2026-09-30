#!/bin/sh
# INKWAVE Godot 移植：唯一的验证入口。
#
# 依次执行：
#   1. 素材导入（仅在 assets/ 比上次戳记更新时）
#   2. 每个导出器的 --check（需要 node；只读，不写生成物）
#   3. 解析预检（失败立即停止），再执行其余无界面规则短测
#
# 用法：
#   tools/run_checks.sh
#   GODOT=/path/to/godot NODE=/path/to/node tools/run_checks.sh
#
# 退出码非 0 表示有任一步骤失败。判定一个短测通过的条件是：退出码为 0、
# 输出有单独的 PASS: 行，且日志中没有脚本/解析错误。
#
# 规范要求“声明已移植必须附可重现用例与结果”，本脚本就是那个可重现入口。
set -u

HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

GODOT="${GODOT:-}"
if [ -z "$GODOT" ]; then
  if [ -x /Applications/Godot.app/Contents/MacOS/Godot ]; then
    GODOT=/Applications/Godot.app/Contents/MacOS/Godot
  elif command -v godot >/dev/null 2>&1; then
    GODOT=$(command -v godot)
  fi
fi
if [ -z "$GODOT" ]; then
  printf '%s\n' '未找到 Godot 4.8；请设置 GODOT 或安装 Godot.app。' >&2
  exit 2
fi

NODE="${NODE:-}"
if [ -z "$NODE" ] && command -v node >/dev/null 2>&1; then
  NODE=$(command -v node)
fi
if [ -z "$NODE" ] || ! command -v "$NODE" >/dev/null 2>&1; then
  printf '%s\n' '未找到 Node；四个导出器检查必需。请设置 NODE=/path/to/node。' >&2
  exit 2
fi

printf 'Godot: %s\n' "$("$GODOT" --version 2>/dev/null | tail -1)"
printf 'Node : %s\n\n' "$NODE"

# --- 1. 素材导入 ---------------------------------------------------------------
mkdir -p "$HERE/.godot"
STAMP="$HERE/.godot/.inkwave-assets-ready"
if [ ! -f "$STAMP" ] || [ -n "$(find "$HERE/assets" -type f -newer "$STAMP" -print -quit)" ]; then
  if ! "$GODOT" --headless --log-file "$HERE/.godot/import.engine.log" --path "$HERE" --import >"$HERE/.godot/import.log" 2>&1; then
    printf 'FAIL  素材导入失败，详见 %s\n' "$HERE/.godot/import.log"
    exit 1
  fi
  touch "$STAMP"
fi

failed=0
passed=0

# --- 2. 导出器 --check ---------------------------------------------------------
EXPORTERS="export_tidewater_map export_tidewater_surfaces export_weapon_config export_ui_icons"
for name in $EXPORTERS; do
    output=$("$NODE" "$HERE/tools/$name.mjs" --check 2>&1)
    status=$?
    if [ "$status" -eq 0 ]; then
      printf 'PASS  %-28s --check\n' "$name"
      passed=$((passed + 1))
    else
      printf 'FAIL  %-28s --check (exit=%s)\n' "$name" "$status"
      printf '%s\n' "$output" | grep -vE 'Reparsing|MODULE_TYPELESS|trace-warnings' | tail -6 | sed 's/^/      /'
      failed=$((failed + 1))
    fi
done

printf '\n'

# --- 3. 规则短测 ---------------------------------------------------------------
# The macOS sandbox cannot query system CA certificates; this exact engine
# diagnostic is unrelated to the local scene checks. Other ERROR lines fail.
NOISE='^ERROR: Condition "ret != noErr" is true\. Returning: ""$'
CHECK_TIMEOUT="${CHECK_TIMEOUT:-120}"

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
  run_limited "$GODOT" --headless --log-file "$HERE/.godot/$name.engine.log" --path "$HERE" --script "res://tools/$name.gd" >"$log" 2>&1
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
if ! run_check "$HERE/tools/check_scripts_parse.gd"; then
  printf '\n解析预检失败，停止后续规则短测。通过 %d，失败 %d\n' "$passed" "$failed"
  printf '日志保留在 %s/*.log\n' "$HERE/.godot"
  exit 1
fi

for path in "$HERE"/tools/check_*.gd; do
  [ "$(basename "$path")" = check_scripts_parse.gd ] && continue
  run_check "$path"
done

printf '\n%s\n' "----------------------------------------"
printf '通过 %d，失败 %d\n' "$passed" "$failed"
if [ "$failed" -ne 0 ]; then
  printf '日志保留在 %s/*.log\n' "$HERE/.godot"
  exit 1
fi
printf '全部通过。\n'
