# Shared by run.sh, export_macos.sh and tools/run_checks.sh (POSIX sh).
# Callers set INKWAVE_PROJECT_DIR before sourcing this file.

inkwave_find_godot() {
  if [ -z "${GODOT:-}" ]; then
    if [ -x /Applications/Godot.app/Contents/MacOS/Godot ]; then
      GODOT=/Applications/Godot.app/Contents/MacOS/Godot
    elif command -v godot >/dev/null 2>&1; then
      GODOT=$(command -v godot)
    fi
  fi
  if [ -z "${GODOT:-}" ] || ! command -v "$GODOT" >/dev/null 2>&1; then
    printf '%s\n' '未找到 Godot 4.8；请设置 GODOT=/path/to/godot。' >&2
    return 2
  fi
}

inkwave_import_assets() {
  mkdir -p "$INKWAVE_PROJECT_DIR/.godot"
  inkwave_stamp="$INKWAVE_PROJECT_DIR/.godot/.inkwave-assets-ready"
  # Directory timestamps also catch added/deleted assets. Exports force an
  # editor scan so script/scene registrations cannot come from a stale cache.
  if [ "${1:-}" = force ] || [ ! -f "$inkwave_stamp" ] ||
    [ "$INKWAVE_PROJECT_DIR/project.godot" -nt "$inkwave_stamp" ] ||
    [ -n "$(find "$INKWAVE_PROJECT_DIR/assets" -newer "$inkwave_stamp" -print -quit)" ]; then
    if ! "$GODOT" --headless --log-file "$INKWAVE_PROJECT_DIR/.godot/import.engine.log" \
      --path "$INKWAVE_PROJECT_DIR" --import >"$INKWAVE_PROJECT_DIR/.godot/import.log" 2>&1; then
      printf 'FAIL  素材导入失败，详见 %s\n' "$INKWAVE_PROJECT_DIR/.godot/import.log" >&2
      return 1
    fi
    touch "$inkwave_stamp"
  fi
}
