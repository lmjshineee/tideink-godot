#!/usr/bin/env python3
"""DS-04: isolated real-engine checks; no production scenes or assets are run.

Run with python3 tools/test_parse_gate.py. GODOT and NODE may override binaries.
Exporter stubs isolate the runner's ordering from unrelated asset checks.
"""

import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


TOOLS = Path(__file__).resolve().parent
GODOT = os.environ.get("GODOT") or shutil.which("godot") or \
    "/Applications/Godot.app/Contents/MacOS/Godot"
NODE = os.environ.get("NODE") or shutil.which("node")


def require(condition, message, output):
    if not condition:
        raise AssertionError(f"{message}\n{output}")


def main():
    if not NODE:
        raise RuntimeError("Node is required for the isolated runner check")
    with tempfile.TemporaryDirectory(prefix="inkwave-parse-gate-") as directory:
        project = Path(directory)
        tools = project / "tools"
        tools.mkdir()
        (project / "assets").mkdir()
        (project / ".godot").mkdir()
        (project / ".godot/.inkwave-assets-ready").touch()
        (project / "project.godot").write_text('config_version=5\n')
        for name in ("check_scripts_parse.gd", "run_checks.sh"):
            shutil.copy2(TOOLS / name, tools / name)
        exporters = re.search(r'^EXPORTERS="([^"]+)"$',
                              (tools / "run_checks.sh").read_text(), re.MULTILINE)
        if exporters is None:
            raise RuntimeError("Cannot find the runner's exporter inventory")
        for name in exporters.group(1).split():
            (tools / f"{name}.mjs").write_text('console.log("stub exporter");\n')
        # This sorts before the parse gate, so the old glob-based runner launches it.
        sentinel = tools / "check_a_sentinel.gd"
        sentinel.write_text('extends SceneTree\nfunc _initialize():\n'
                            '\tprint("SENTINEL: dependent scene ran")\n'
                            '\tprint("PASS: sentinel")\n\tquit()\n')
        valid = project / "valid.gd"
        valid.write_text('extends Node\n')

        def gate():
            return subprocess.run([
                GODOT, "--headless", "--log-file", str(project / "gate.engine.log"),
                "--path", directory, "--script", "res://tools/check_scripts_parse.gd",
            ], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=15)

        result = gate()
        require(result.returncode == 0 and "PASS:" in result.stdout,
                "valid script must pass", result.stdout)
        print("PASS: valid production script")

        broken = project / "broken.gd"
        broken.write_text('extends Node\nfunc broken(:\n')
        result = gate()
        require(result.returncode != 0 and "PASS:" not in result.stdout
                and "FAIL: these production scripts do not parse: broken.gd" in result.stdout,
                "syntax error must fail and identify its script", result.stdout)
        print("PASS: syntax error exits nonzero without PASS")
        broken.unlink()

        dependencies = project / "dependencies"
        dependencies.mkdir()
        (dependencies / "bad.gd").write_text('extends Node\nfunc broken(:\n')
        valid.write_text('extends Node\nconst Bad = preload("res://dependencies/bad.gd")\n')
        result = gate()
        require(result.returncode != 0 and "PASS:" not in result.stdout
                and "dependencies/bad.gd" in result.stdout
                and "FAIL: these production scripts do not parse: valid.gd" in result.stdout,
                "broken dependency must fail and identify dependency and consumer", result.stdout)
        print("PASS: broken preloaded dependency is identified")

        def runner():
            return subprocess.run(["sh", str(tools / "run_checks.sh")],
                                  env={**os.environ, "GODOT": GODOT, "NODE": NODE,
                                       "CHECK_TIMEOUT": "5"},
                                  text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                  timeout=20)

        result = runner()
        require(result.returncode != 0 and "FAIL  check_scripts_parse" in result.stdout
                and "check_a_sentinel" not in result.stdout
                and not (project / ".godot/check_a_sentinel.log").exists(),
                "failed preflight must prevent even alphabetically earlier scene checks", result.stdout)
        print("PASS: runner stops before dependent scene checks")

        valid.write_text('extends Node\n')
        result = runner()
        require(result.returncode == 0
                and result.stdout.count("PASS  check_scripts_parse\n") == 1
                and "PASS  check_a_sentinel" in result.stdout,
                "valid preflight must run once and allow scene checks", result.stdout)
        print("PASS: runner continues after a valid preflight, without duplicating it")


if __name__ == "__main__":
    main()
