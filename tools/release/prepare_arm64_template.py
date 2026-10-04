#!/usr/bin/env python3
"""Make an arm64-only release template from the locally installed Godot archive.

Some 4.8 dev archives contain only a universal binary, while the arm64 exporter
requires a .arm64 member. Extracting a slice does not execute the other CPU code.
The installed template is read-only; the generated ZIP stays in .godot/.
"""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile


def main() -> None:
    version = ".".join(sys.argv[1].strip().split(".")[:3])
    project = Path(__file__).resolve().parents[2]
    templates = Path(os.environ.get(
        "GODOT_TEMPLATE_DIR",
        str(Path.home() / "Library/Application Support/Godot/export_templates" / version),
    ))
    source = templates / "macos.zip"
    destination = project / ".godot/arm64-template.zip"
    prefix = "macos_template.app/Contents/MacOS/godot_macos_release."
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="inkwave-arm64-") as temporary:
        native = Path(temporary) / "release.arm64"
        output = Path(temporary) / "template.zip"
        with zipfile.ZipFile(source) as archive:
            if prefix + "arm64" in archive.namelist():
                native.write_bytes(archive.read(prefix + "arm64"))
            else:
                installed_binary = Path(temporary) / "installed-template"
                installed_binary.write_bytes(archive.read(prefix + "universal"))
                subprocess.run([
                    "lipo", str(installed_binary), "-thin", "arm64", "-output", str(native),
                ], check=True)
            architecture = subprocess.check_output(["lipo", "-archs", str(native)], text=True).strip()
            if architecture != "arm64":
                raise RuntimeError(f"Expected arm64 template, got {architecture}")
            with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as target:
                for entry in archive.infolist():
                    if "Contents/MacOS/godot_macos_" in entry.filename:
                        continue
                    content = archive.read(entry)
                    if entry.filename.endswith('/Info.plist'):
                        content = content.replace(b'\t\t<string>x86_64</string>\n', b'')
                        content = content.replace(b'\t\t<key>x86_64</key>\n\t\t<string>$min_version_x86_64</string>\n', b'')
                    target.writestr(entry, content)
                binary = zipfile.ZipInfo(prefix + "arm64")
                binary.external_attr = 0o100755 << 16
                binary.compress_type = zipfile.ZIP_DEFLATED
                target.writestr(binary, native.read_bytes())
        destination.write_bytes(output.read_bytes())
    print(f"Prepared arm64-only template: {destination}")


if __name__ == "__main__":
    main()
