#!/bin/zsh
set -eu
sculpt_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
exec /Applications/Godot.app/Contents/MacOS/Godot --path "$sculpt_dir/../.." --log-file /private/tmp/inkwave-sculpt-studio.log res://experiments/character-sculpt/studio.tscn
