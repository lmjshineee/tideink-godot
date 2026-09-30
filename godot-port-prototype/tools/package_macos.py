#!/usr/bin/env python3
"""Package the already exported arm64 app; no upload or repository mutation."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--version', required=True)
    args = parser.parse_args()
    if not re.fullmatch(r'v\d+\.\d+\.\d+(?:-[a-z0-9]+\.\d+)?', args.version):
        parser.error('version must look like v0.3.0-preview.2')
    project = Path(__file__).resolve().parents[1]
    app = project / 'build/INKWAVE Demo.app'
    plist = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    executable = app / 'Contents/MacOS' / plist['CFBundleExecutable']
    pck = app / 'Contents/Resources/INKWAVE Demo.pck'
    architecture = subprocess.check_output(['lipo', '-archs', str(executable)], text=True).strip()
    if architecture != 'arm64':
        raise RuntimeError('Only arm64 packaging is supported')
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    stem = f'INKWAVE-Godot-Demo-{args.version}-macOS-arm64'
    stage = project / 'build' / stem
    stage.mkdir(exist_ok=True)
    subprocess.run(['ditto', str(app), str(stage / app.name)], check=True)
    shutil.copytree(project / 'licenses', stage / 'licenses', dirs_exist_ok=True)
    shutil.copy2(project / 'THIRD_PARTY_NOTICES.md', stage / 'THIRD_PARTY_NOTICES.md')
    shutil.copy2(project / 'RELEASE_NOTES.md', stage / 'RELEASE_NOTES.md')
    (stage / 'README.md').write_text(f'''# INKWAVE {args.version} · 本地修复候选

解压后打开 INKWAVE Demo.app。仅 Apple Silicon / arm64。
应用为临时签名、未经 Apple 公证；若首次打开被 macOS 拦截，可在系统设置的隐私与安全性中确认允许打开。

默认单机 5v5，支持 Tidewater / Kelpline 和 1v1。赛前选择武器、外观、队色与时长。
WASD 移动，鼠标瞄准，空格跳跃，Shift 在己方墨面/墨墙进入墨鱼，左键主武器，右键投弹，F/Q 大招。
Tab 展开战术地图和队伍状态，Esc 暂停；设置可保存帧率、画面精度、界面缩放和灵敏度。
默认 30 FPS / 75% 画面精度。持续温度和完整对局尚未验收；具体桥梁漏染位置未定位。

修复范围与未完成项见 RELEASE_NOTES.md；本包尚未公开发布。
''')
    source_head = subprocess.check_output(['git', '-C', str(project.parent), 'rev-parse', 'HEAD'], text=True).strip()
    manifest = {
        'version': args.version, 'engine': 'Godot 4.8.dev6', 'architecture': architecture,
        'bundle_version': plist['CFBundleShortVersionString'], 'source_head': source_head,
        'executable_sha256': sha(executable), 'pck_sha256': sha(pck),
        'signature': 'ad-hoc; codesign --verify --deep --strict passed', 'notarized': False,
        'published': False,
    }
    (stage / 'BUILD.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    archive = project / 'build' / f'{stem}.zip'
    subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(stage), str(archive)], check=True)
    subprocess.run(['unzip', '-tq', str(archive)], check=True)
    checksum = project / 'build' / f'INKWAVE-Godot-Demo-{args.version}-SHA256SUMS.txt'
    checksum.write_text(f'{sha(archive)}  {archive.name}\n')
    print(json.dumps({'archive': str(archive), 'sha256': sha(archive), 'bytes': archive.stat().st_size}, ensure_ascii=False))


if __name__ == '__main__':
    main()
