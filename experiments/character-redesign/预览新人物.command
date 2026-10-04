#!/bin/zsh
set -eu
studio_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
exec /Applications/Godot.app/Contents/MacOS/Godot --path "$studio_dir/../.." --log-file /private/tmp/inkwave-wave-studio.log res://experiments/character-redesign/studio.tscn
