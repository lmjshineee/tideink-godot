#!/usr/bin/env python3
"""Run DS-05 with default and nondefault exports in isolated minimal projects."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    project = Path(__file__).resolve().parents[1]
    godot = os.environ.get("GODOT") or shutil.which("godot") or \
        "/Applications/Godot.app/Contents/MacOS/Godot"
    payload = json.loads((project / "assets/weapons.json").read_text())
    default_speed = payload["player"]["runSpeed"]
    for speed in (default_speed, 12.0):
        with tempfile.TemporaryDirectory(prefix="inkwave-visual-config-") as directory:
            isolated = Path(directory)
            (isolated / "tools").mkdir()
            (isolated / "assets/maps").mkdir(parents=True)
            (isolated / "project.godot").write_text("config_version=5\n")
            for name in ("tidewater_character_visual.gd", "tidewater_walker.gd",
                         "tidewater_bot.gd", "team_palette.gd", "match_setup.gd", "gameplay_rules.gd", "equipment_catalog.gd"):
                shutil.copy2(project / name, isolated / name)
            for shader in project.glob("character_*.gdshader"):
                shutil.copy2(shader, isolated / shader.name)
            shutil.copy2(project / "tools/check_tidewater_visual_config.gd",
                         isolated / "tools/check_tidewater_visual_config.gd")
            shutil.copy2(project / "assets/maps/tidewater.json",
                         isolated / "assets/maps/tidewater.json")
            payload["player"]["runSpeed"] = speed
            (isolated / "assets/weapons.json").write_text(json.dumps(payload))
            result = subprocess.run([
                godot, "--headless", "--log-file", str(isolated / "engine.log"),
                "--path", directory, "--script", "res://tools/check_tidewater_visual_config.gd",
                "--quit-after", "90",
            ], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=15)
            lines = result.stdout.splitlines()
            # Match the suite's single known macOS sandbox CA diagnostic exemption.
            errors = [line for line in lines if line.startswith(("ERROR:", "SCRIPT ERROR:", "FAIL:"))
                      and line != 'ERROR: Condition "ret != noErr" is true. Returning: ""']
            passes = [line for line in lines if line.startswith("PASS:")]
            if result.returncode != 0 or errors or not passes:
                raise AssertionError(f"runSpeed={speed} failed (exit={result.returncode})\n{result.stdout}")
            print("\n".join(passes))


if __name__ == "__main__":
    main()
