#!/bin/zsh
set -eu
wardrobe_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
exec /Applications/Godot.app/Contents/MacOS/Godot \
  --path "$wardrobe_dir/.." --log-file /private/tmp/inkwave-wardrobe-gallery.log \
  res://character-sculpt/gallery.tscn
