#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SCENE=
RENDERER=forward_plus
while [ "$#" -gt 0 ]; do
  case "$1" in
    --flat) SCENE=res://main.tscn ;;
    --tidewater) SCENE=res://tidewater_play.tscn ;;
    --compatibility) RENDERER=gl_compatibility ;;
    *) printf '%s\n' '用法: run.sh [--flat|--tidewater] [--compatibility]' >&2; exit 2 ;;
  esac
  shift
done
if [ -x /Applications/Godot.app/Contents/MacOS/Godot ]; then
  GODOT=/Applications/Godot.app/Contents/MacOS/Godot
elif command -v godot >/dev/null 2>&1; then
  GODOT=$(command -v godot)
else
  printf '%s\n' 'Godot 4.8 未找到；请安装 Godot.app 到 /Applications。' >&2
  exit 1
fi

mkdir -p "$HERE/.godot"
STAMP="$HERE/.godot/.inkwave-assets-ready"
if [ ! -f "$STAMP" ] || [ -n "$(find "$HERE/assets" -type f -newer "$STAMP" -print -quit)" ]; then
  "$GODOT" --log-file "$HERE/.godot/import.log" --headless --path "$HERE" --import
  touch "$STAMP"
fi
if [ -n "$SCENE" ]; then
  exec "$GODOT" --log-file "$HERE/.godot/run.log" --path "$HERE" --rendering-method "$RENDERER" "$SCENE"
fi
exec "$GODOT" --log-file "$HERE/.godot/run.log" --path "$HERE" --rendering-method "$RENDERER"
