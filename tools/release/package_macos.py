#!/usr/bin/env python3
"""Package an attested arm64 export; never infer its source from current HEAD."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

from build_metadata import identity, inventory, production_files, sha, validate_receipt


def validate_release(receipt, metadata, sources, app_files, version, source_commit=None):
    validate_receipt(receipt, metadata, sources, app_files)
    if version != 'v' + metadata['version']:
        raise ValueError('release tag differs from exported version')
    if source_commit and source_commit != receipt['source_head']:
        raise ValueError('source-commit differs from the actual export receipt')


def evidence_paths(project, values):
    paths = []
    evidence_root = (project / 'render-evidence').resolve()
    for value in values:
        path = (project / value).resolve()
        if evidence_root not in path.parents or not path.is_dir():
            raise ValueError('evidence must be an existing render-evidence subdirectory')
        if path in paths:
            raise ValueError('duplicate evidence directory')
        paths.append(path)
    return paths


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--version', required=True)
    parser.add_argument('--source-commit', help='Optional assertion against captured export SHA')
    parser.add_argument('--release-url', help='GitHub release page for this build')
    parser.add_argument('--evidence', action='append', default=[], help='Current evidence subdirectory; repeatable')
    parser.add_argument('--force', action='store_true', help='Replace this version of the local ZIP')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[2]
    receipt = json.loads((project / 'build/export-receipt.json').read_text())
    metadata = identity(project)
    app = project / 'build' / metadata['app_name']
    validate_release(receipt, metadata, production_files(project), inventory([app], app),
                     args.version, args.source_commit)
    executable = app / receipt['executable']
    if subprocess.check_output(['lipo', '-archs', str(executable)], text=True).strip() != 'arm64':
        raise ValueError('only arm64 packaging is supported')
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    evidence = evidence_paths(project, args.evidence)
    stem = f"{metadata['name']}-{args.version}-macOS-arm64"
    archive = project / 'build' / (stem + '.zip')
    if archive.exists() and not args.force:
        raise FileExistsError('archive exists; use --force for an intentional rebuild')
    with tempfile.TemporaryDirectory(prefix='tideink-package-', dir=project / 'build') as temp:
        stage = Path(temp) / stem
        stage.mkdir()
        subprocess.run(['ditto', str(app), str(stage / app.name)], check=True)
        shutil.copytree(project / 'licenses', stage / 'licenses')
        shutil.copy2(project / 'THIRD_PARTY_NOTICES.md', stage / 'THIRD_PARTY_NOTICES.md')
        shutil.copytree(project / 'docs', stage / 'docs')
        for path in evidence:
            shutil.copytree(path, stage / path.relative_to(project))
        (stage / 'README.md').write_text(f'''# {metadata['name']}（潮墨）· {args.version}

解压后打开 **{app.name}**。仅 Apple Silicon / arm64。应用使用临时签名，未经 Apple 公证；若首次打开被系统拦截，可在系统设置 → 隐私与安全性中允许打开。

原 INKWAVE 原生项目现名 TideInk；已有美术、音频、字体及来源许可保留。
当前为单机玩家＋机器人，支持 1v1 / 5v5、90 / 180 秒、七张地图、十九套预生成布局、八武器、九道具、八天赋。
主菜单进入配装，选定地图／装备后开战；天赋整局锁定，道具 CD 跨死亡保留。死亡后由玩家选择基地、队友或信标，并确认出场。

WASD 移动，鼠标瞄准，左键主武器，空格跳跃，Shift 潜墨／墨墙攀爬，E / 右键道具，F / Q 大招，J 跳跃地点选择，Tab 战术地图，Esc 暂停。结算 Enter 返回主菜单。
结算分别显示累计涂地 m² 与存活积分 p；两者可以不同，最终胜负来自 CPU 墨格覆盖率。
默认 Forward+ / Metal，30 FPS / 75% 精度；详细规则见 [玩法](docs/GAMEPLAY.md)、[配装](docs/CREATIVE_LOADOUTS.md)和[版本记录](docs/RELEASE_NOTES.md)。

本包的源码提交、引擎、输入／应用文件哈希见 BUILD.json；其中 source_head 来自导出前捕获的干净生产源码提交。
随包证据记录其各自的源码及方法，历史对局不能直接代表此新包或真人手感。真人配装平衡、全地图完整对局、长期温度、桥梁漏染及联网仍未验收。
发布页面：{args.release_url or '本地构建'}
''')
        manifest = dict(receipt)
        manifest.update({'version': args.version, 'release_url': args.release_url,
                         'evidence_files': inventory(evidence, project)})
        (stage / 'BUILD.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
        if inventory([stage / app.name], stage / app.name) != receipt['app_files']:
            raise ValueError('staging changed exported app bytes')
        # Test a temporary archive first, preserving an older ZIP on failure.
        temporary_archive = Path(temp) / 'package.zip'
        subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent',
                        str(stage), str(temporary_archive)], check=True)
        subprocess.run(['unzip', '-tq', str(temporary_archive)], check=True,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        temporary_archive.replace(archive)
    checksum = project / 'build' / (stem + '-SHA256SUMS.txt')
    digest = sha(archive)
    checksum.write_text(f'{digest}  {archive.name}\n')
    print(json.dumps({'archive': str(archive), 'sha256': digest, 'bytes': archive.stat().st_size,
                      'source_head': receipt['source_head']}, ensure_ascii=False))


if __name__ == '__main__':
    main()
