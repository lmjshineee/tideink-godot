#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SCENE=
RENDERER=forward_plus
while [ "$#" -gt 0 ]; do
  case "$1" in
    --flat) SCENE=res://scenes/legacy/main.tscn ;;
    --tidewater) SCENE=res://scenes/match/tidewater_play.tscn ;;
    --compatibility) RENDERER=gl_compatibility ;;
    *) printf '%s\n' '用法: run.sh [--flat|--tidewater] [--compatibility]' >&2; exit 2 ;;
  esac
  shift
done
INKWAVE_PROJECT_DIR="$HERE"
. "$HERE/tools/lib/runtime.sh"
inkwave_find_godot
inkwave_import_assets
if [ -n "$SCENE" ]; then
  exec "$GODOT" --log-file "$HERE/.godot/run.log" --path "$HERE" --rendering-method "$RENDERER" "$SCENE"
fi
exec "$GODOT" --log-file "$HERE/.godot/run.log" --path "$HERE" --rendering-method "$RENDERER"
