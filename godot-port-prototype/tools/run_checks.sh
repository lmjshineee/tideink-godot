#!/bin/sh
# INKWAVE Godot 移植：唯一的验证入口。
#
# 依次执行：
#   1. 素材导入（仅在 assets/ 比上次戳记更新时）
#   2. 每个导出器的 --check（需要 node；只读，不写生成物）
#   3. tools/check_*.gd 的每个无界面规则短测
#
# 用法：
#   tools/run_checks.sh
#   GODOT=/path/to/godot NODE=/path/to/node tools/run_checks.sh
#
# 退出码非 0 表示有任一步骤失败。判定一个短测通过的条件是：退出码为 0、
# 输出含 PASS，且日志中没有脚本/解析错误（不含沙箱里 user:// 目录不可写的噪声）。
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

printf 'Godot: %s\n' "$("$GODOT" --version 2>/dev/null | tail -1)"
printf 'Node : %s\n\n' "${NODE:-（未找到，导出器检查将跳过）}"

# --- 1. 素材导入 ---------------------------------------------------------------
mkdir -p "$HERE/.godot"
STAMP="$HERE/.godot/.inkwave-assets-ready"
if [ ! -f "$STAMP" ] || [ -n "$(find "$HERE/assets" -type f -newer "$STAMP" -print -quit)" ]; then
  if ! "$GODOT" --headless --path "$HERE" --import >"$HERE/.godot/import.log" 2>&1; then
    printf 'FAIL  素材导入失败，详见 %s\n' "$HERE/.godot/import.log"
    exit 1
  fi
  touch "$STAMP"
fi

failed=0
passed=0

# --- 2. 导出器 --check ---------------------------------------------------------
EXPORTERS="export_tidewater_map export_tidewater_surfaces export_weapon_config export_ui_icons"
if [ -n "$NODE" ]; then
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
else
  printf 'SKIP  导出器 --check（未找到 node；用 NODE=/path/to/node 指定）\n'
fi

printf '\n'

# --- 3. 规则短测 ---------------------------------------------------------------
# 沙箱等环境里 user:// 目录可能不可写，这行日志噪声不算失败。
NOISE='Failed to open.*user://logs|Failed to open log file|Cannot write to user'
for path in "$HERE"/tools/check_*.gd; do
  name=$(basename "$path" .gd)
  log="$HERE/.godot/$name.log"
  "$GODOT" --headless --path "$HERE" --script "res://tools/$name.gd" >"$log" 2>&1
  status=$?
  problems=$(grep -E 'SCRIPT ERROR|Parse Error|Invalid call|Failed to load' "$log" | grep -vE "$NOISE" | head -3)
  if [ "$status" -eq 0 ] && grep -q 'PASS' "$log" && [ -z "$problems" ]; then
    printf 'PASS  %s\n' "$name"
    passed=$((passed + 1))
  else
    printf 'FAIL  %s (exit=%s)\n' "$name" "$status"
    grep -E 'FAIL:|SCRIPT ERROR|Parse Error|Invalid call' "$log" | head -4 | sed 's/^/      /'
    if [ -n "$problems" ]; then
      printf '%s\n' "$problems" | sed 's/^/      /'
    elif ! grep -q 'PASS' "$log"; then
      tail -4 "$log" | sed 's/^/      /'
    fi
    failed=$((failed + 1))
  fi
done

printf '\n%s\n' "----------------------------------------"
printf '通过 %d，失败 %d\n' "$passed" "$failed"
if [ "$failed" -ne 0 ]; then
  printf '日志保留在 %s/*.log\n' "$HERE/.godot"
  exit 1
fi
printf '全部通过。\n'
