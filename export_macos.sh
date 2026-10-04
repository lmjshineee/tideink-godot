#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP_NAME=$(python3 "$PROJECT_DIR/tools/release/build_metadata.py" identity --field app_name)
OUTPUT_APP="$PROJECT_DIR/build/$APP_NAME"

INKWAVE_PROJECT_DIR="$PROJECT_DIR"
. "$PROJECT_DIR/tools/lib/runtime.sh"
inkwave_find_godot
mkdir -p "$PROJECT_DIR/build"
python3 "$PROJECT_DIR/tools/release/prepare_arm64_template.py" "$("$GODOT" --version)"
inkwave_import_assets force
python3 "$PROJECT_DIR/tools/release/build_metadata.py" prepare --engine "$("$GODOT" --version)"
"$GODOT" --headless --log-file "$PROJECT_DIR/.godot/export.log" --path "$PROJECT_DIR" \
  --export-release macOS "$OUTPUT_APP"

APP_EXEC=$(find "$OUTPUT_APP/Contents/MacOS" -type f -perm -111 -print -quit 2>/dev/null || true)
if [ ! -d "$OUTPUT_APP/Contents/MacOS" ] || [ -z "$APP_EXEC" ]; then
  printf '%s\n' '导出命令结束，但没有找到可执行的 macOS .app。请检查 .godot/export.log。' >&2
  exit 1
fi

# Project policy: Apple Silicon only. Reject a stale or misconfigured fat build.
if [ "$(lipo -archs "$APP_EXEC")" != "arm64" ]; then
  printf '%s\n' '导出架构不符合项目约定：只允许 arm64。' >&2
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
"$APP_EXEC" --headless --quit-after 2 --log-file "$PROJECT_DIR/.godot/export-smoke.log"
check_log "$PROJECT_DIR/.godot/export-smoke.log"
python3 "$PROJECT_DIR/tools/release/build_metadata.py" finish

printf '已导出：%s\n' "$OUTPUT_APP"
