#!/usr/bin/env python3
"""Explicitly record local assets after their semantic checks pass."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets/integrity.json"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="write the reviewed asset inventory")
    args = parser.parse_args()
    if not args.write:
        parser.error("pass --write only after validating intentional asset changes")
    previous = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
    files = {}
    for path in sorted((ROOT / "assets").rglob("*")):
        relative = path.relative_to(ROOT)
        if not path.is_file() or path == MANIFEST or path.suffix in {".import", ".uid"}:
            continue
        if any(part.startswith(".") for part in relative.parts):
            continue
        content = path.read_bytes()
        files[relative.as_posix()] = {"sha256": hashlib.sha256(content).hexdigest(), "bytes": len(content)}
    if not files:
        raise RuntimeError("refusing to record an empty asset inventory")
    data = {"schema_version": 1,
            "origin_baseline": previous.get("origin_baseline", "aaf038c"),
            "scope": "Local Godot assets; imported metadata and this manifest are excluded",
            "files": files}
    MANIFEST.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print(f"Recorded {len(files)} local assets; review assets/integrity.json before committing")


if __name__ == "__main__":
    main()
