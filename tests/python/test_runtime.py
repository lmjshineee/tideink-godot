#!/usr/bin/env python3
"""Exercise shared launch/import behavior with an isolated executable and assets."""
import os
from pathlib import Path
import subprocess
import tempfile

RUNTIME = Path(__file__).resolve().parents[2] / "tools/lib/runtime.sh"

def main():
    with tempfile.TemporaryDirectory(prefix="inkwave-runtime-") as directory:
        project = Path(directory) / "project with spaces"
        assets = project / "assets"
        assets.mkdir(parents=True)
        (project / "project.godot").write_text("config_version=5\n")
        asset = assets / "sample.svg"
        asset.write_text("<svg/>\n")
        trace = project / "calls"
        executable = project / "chosen godot"
        executable.write_text('#!/bin/sh\nprintf "called\\n" >> "$INKWAVE_TEST_TRACE"\n'
                              'test "${INKWAVE_TEST_FAIL:-0}" != 1\n')
        executable.chmod(0o755)
        env = {**os.environ, "GODOT": str(executable), "INKWAVE_TEST_TRACE": str(trace)}
        program = ('set -eu; INKWAVE_PROJECT_DIR=$1; . "$2"; '
                   'inkwave_find_godot; test "$GODOT" = "$3"; inkwave_import_assets "$4"')

        def run(mode="", fail=False):
            return subprocess.run(["sh", "-c", program, "runtime-test", str(project),
                                   str(RUNTIME), str(executable), mode],
                                  env={**env, "INKWAVE_TEST_FAIL": "1" if fail else "0"},
                                  text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                  timeout=10)

        def calls():
            return len(trace.read_text().splitlines())

        assert run().returncode == 0 and calls() == 1, "explicit GODOT and paths with spaces"
        assert run().returncode == 0 and calls() == 1, "reuse a completed import"
        assert run("force").returncode == 0 and calls() == 2, "exports force a fresh scan"
        stamp = project / ".godot/.inkwave-assets-ready"
        # All remaining files are older: deletion must be detected by the directory.
        os.utime(stamp, (100, 100))
        os.utime(project / "project.godot", (50, 50))
        asset.unlink()
        assert run().returncode == 0 and calls() == 3, "deleted asset triggers import"
        previous_stamp = stamp.stat().st_mtime_ns
        assert run("force", fail=True).returncode != 0, "failed engine import must stop caller"
        assert stamp.stat().st_mtime_ns == previous_stamp, "failed import must not mark cache ready"
        assert run("force").returncode == 0 and calls() == 5, "failed import is retryable"
        print("PASS: selected engine, spaced paths, cache reuse, forced/deletion import, failure and retry")

if __name__ == "__main__":
    main()
