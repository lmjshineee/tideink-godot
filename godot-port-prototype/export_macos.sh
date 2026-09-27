#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OUTPUT_APP="$PROJECT_DIR/build/INKWAVE Demo.app"

if [ -x /Applications/Godot.app/Contents/MacOS/Godot ]; then
  GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
elif command -v godot >/dev/null 2>&1; then
  GODOT_BIN=$(command -v godot)
else
  printf '%s\n' 'Godot 4.8 未找到；请安装 Godot.app 到 /Applications。' >&2
  exit 1
fi

mkdir -p "$PROJECT_DIR/build" "$PROJECT_DIR/.godot"
"$GODOT_BIN" --headless --log-file "$PROJECT_DIR/.godot/import.log" --path "$PROJECT_DIR" --import
"$GODOT_BIN" --headless --log-file "$PROJECT_DIR/.godot/export.log" --path "$PROJECT_DIR" \
  --export-release macOS "$OUTPUT_APP"

APP_EXEC=$(find "$OUTPUT_APP/Contents/MacOS" -type f -perm -111 -print -quit 2>/dev/null || true)
if [ ! -d "$OUTPUT_APP/Contents/MacOS" ] || [ -z "$APP_EXEC" ]; then
  printf '%s\n' '导出命令结束，但没有找到可执行的 macOS .app。请检查 .godot/export.log。' >&2
  exit 1
fi

check_log() {
  if grep -E '^(SCRIPT ERROR:|ERROR:|WARNING:)' "$1" | \
    grep -v '^ERROR: Condition "ret != noErr" is true. Returning: ""$'; then
    printf 'Godot 日志有脚本或场景错误：%s\n' "$1" >&2
    exit 1
  fi
}

check_log "$PROJECT_DIR/.godot/import.log"
check_log "$PROJECT_DIR/.godot/export.log"
codesign --verify --deep --strict "$OUTPUT_APP"
"$APP_EXEC" --headless --quit-after 2 --log-file "$PROJECT_DIR/.godot/export-smoke.log"
check_log "$PROJECT_DIR/.godot/export-smoke.log"

printf '已导出：%s\n' "$OUTPUT_APP"
