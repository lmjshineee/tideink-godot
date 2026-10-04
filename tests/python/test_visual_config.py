#!/usr/bin/env python3
"""Run DS-05 with default and nondefault exports in isolated minimal projects."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    project = Path(__file__).resolve().parents[2]
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
            shutil.copytree(project / "src", isolated / "src")
            shutil.copytree(project / "shaders", isolated / "shaders")
            (isolated / "tests/godot").mkdir(parents=True)
            (isolated / "assets/fonts").mkdir()
            shutil.copy2(project / "assets/fonts/TitanOne-latin.woff2",
                         isolated / "assets/fonts/TitanOne-latin.woff2")
            shutil.copy2(project / "tests/godot/check_tidewater_visual_config.gd",
                         isolated / "tests/godot/check_tidewater_visual_config.gd")
            shutil.copy2(project / "assets/maps/tidewater.json",
                         isolated / "assets/maps/tidewater.json")
            payload["player"]["runSpeed"] = speed
            (isolated / "assets/weapons.json").write_text(json.dumps(payload))
            subprocess.run([godot, "--headless", "--log-file", str(isolated / "import.log"),
                            "--path", directory, "--import"],
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           check=True, timeout=30)
            result = subprocess.run([
                godot, "--headless", "--log-file", str(isolated / "engine.log"),
                "--path", directory, "--script", "res://tests/godot/check_tidewater_visual_config.gd",
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
