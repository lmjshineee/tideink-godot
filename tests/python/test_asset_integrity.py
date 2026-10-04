#!/usr/bin/env python3
"""Real-engine negative checks for the local asset gate; no browser or Node."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get("GODOT") or shutil.which("godot") or \
    "/Applications/Godot.app/Contents/MacOS/Godot"


def main():
    with tempfile.TemporaryDirectory(prefix="inkwave-local-asset-gate-") as directory:
        project = Path(directory)
        (project / "tools/lib").mkdir(parents=True)
        (project / "tests/godot").mkdir(parents=True)
        (project / "assets/nested").mkdir(parents=True)
        (project / "project.godot").write_text("config_version=5\n")
        for name in ["tools/lib/asset_inventory.gd", "tests/godot/check_asset_integrity.gd"]:
            shutil.copy2(ROOT / name, project / name)
        asset = project / "assets/nested/sample.bin"
        asset.write_bytes(b"verified local asset")
        manifest = {"schema_version": 1, "files": {"assets/nested/sample.bin": {
            "sha256": hashlib.sha256(asset.read_bytes()).hexdigest(), "bytes": asset.stat().st_size}}}
        manifest_path = project / "assets/integrity.json"
        manifest_path.write_text(json.dumps(manifest))

        def gate(pass_expected, marker):
            result = subprocess.run([GODOT, "--headless", "--path", directory,
                "--log-file", str(project / "engine.log"),
                "--script", "res://tests/godot/check_asset_integrity.gd"],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=15)
            assert (result.returncode == 0) == pass_expected and marker in result.stdout, result.stdout
            if not pass_expected:
                assert "PASS:" not in result.stdout, result.stdout

        gate(True, "PASS: 1 local asset")
        print("PASS: valid nested asset and complete inventory")
        asset.write_bytes(b"corrupt local asset")
        gate(False, "asset hash mismatch")
        print("PASS: corrupt asset fails")
        asset.unlink()
        gate(False, "missing asset")
        print("PASS: missing asset fails")
        asset.write_bytes(b"verified local asset")
        extra = project / "assets/extra.bin"
        extra.write_bytes(b"unreviewed")
        gate(False, "unrecorded asset")
        print("PASS: added asset requires an intentional manifest update")
        extra.unlink()
        (project / "assets/nested/sample.bin.import").write_text("editor metadata")
        gate(True, "PASS: 1 local asset")
        print("PASS: regenerated import metadata is excluded")
        manifest["files"] = {}
        manifest_path.write_text(json.dumps(manifest))
        gate(False, "must not be empty")
        print("PASS: empty inventory fails")


if __name__ == "__main__":
    main()
