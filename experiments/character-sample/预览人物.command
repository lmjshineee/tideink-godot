#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT=$(CDPATH= cd -- "$HERE/../.." && pwd)
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
if [ ! -x "$GODOT" ]; then
  printf '%s\n' '没有找到 /Applications/Godot.app，请先安装 Godot。'
  exit 1
fi
# Import only when the sample asset or editor cache is new.
if [ ! -f "$HERE/.preview-ready" ] || [ "$HERE/wave.glb" -nt "$HERE/.preview-ready" ] || [ ! -d "$PROJECT/.godot/imported" ]; then
  "$GODOT" --headless --path "$PROJECT" --log-file "$PROJECT/.godot/sample-import.log" --import
  touch "$HERE/.preview-ready"
fi
exec "$GODOT" --path "$PROJECT" --log-file "$PROJECT/.godot/sample-studio.log" res://experiments/character-sample/studio.tscn
