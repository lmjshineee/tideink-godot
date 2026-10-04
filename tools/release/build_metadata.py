#!/usr/bin/env python3
"""Bind a native export to committed production inputs and exact app bytes."""
import argparse
import configparser
import fnmatch
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

PRODUCTION = ('project.godot', 'export_presets.cfg', 'THIRD_PARTY_NOTICES.md',
              'src', 'scenes', 'shaders', 'assets', 'licenses', 'export_macos.sh',
              'tools/lib/runtime.sh', 'tools/release/build_metadata.py',
              'tools/release/prepare_arm64_template.py')


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def read_config(path):
    config = configparser.ConfigParser(interpolation=None, strict=False)
    # Godot has config_version before its first INI section. A synthetic root
    # works on all supported Python versions, including strict configparser.
    config.read_string('[godot_root]\n' + path.read_text(), source=str(path))
    return config


def identity(project):
    config = read_config(project / 'project.godot')
    preset = read_config(project / 'export_presets.cfg')
    name = json.loads(config['application']['config/name'])
    version = json.loads(config['application']['config/version'])
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9 _-]*', name):
        raise ValueError('application name must be a safe native bundle basename')
    if not re.fullmatch(r'\d+\.\d+\.\d+(?:-[a-z0-9]+\.\d+)?', version):
        raise ValueError('invalid project version')
    app_name = name + '.app'
    if json.loads(preset['preset.0']['export_path']) != 'build/' + app_name:
        raise ValueError('export path differs from application name')
    short = json.loads(preset['preset.0.options']['application/short_version'])
    if short != version.split('-')[0]:
        raise ValueError('bundle short version differs from project version')
    if json.loads(preset['preset.0.options']['binary_format/architecture']) != 'arm64':
        raise ValueError('only arm64 export is permitted')
    return {'name': name, 'version': version, 'app_name': app_name,
            'bundle_short_version': short,
            'bundle_build': json.loads(preset['preset.0.options']['application/version']),
            'bundle_identifier': json.loads(preset['preset.0.options']['application/bundle_identifier'])}


def inventory(paths, root):
    files = {}
    for path in paths:
        for item in sorted(path.rglob('*')) if path.is_dir() else [path]:
            if item.is_symlink():
                files[item.relative_to(root).as_posix()] = {'symlink': os.readlink(item)}
            elif item.is_file():
                files[item.relative_to(root).as_posix()] = sha(item)
    return dict(sorted(files.items()))


def production_files(project):
    return {name: value for name, value in inventory(
        [project / name for name in PRODUCTION], project).items()
        if Path(name).name != '.DS_Store'}


def fingerprint(files):
    return hashlib.sha256(json.dumps(files, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def validate_export_dependencies(project):
    preset = read_config(project / 'export_presets.cfg')
    filters = json.loads(preset['preset.0'].get('exclude_filter', '""')).split(',')
    excluded = lambda name: any(fnmatch.fnmatchcase(name, rule) for rule in filters if rule)
    for directory in ('src', 'scenes', 'shaders'):
        for path in (project / directory).rglob('*'):
            if path.suffix not in ('.gd', '.tscn', '.gdshader', '.tres') or excluded(path.relative_to(project).as_posix()):
                continue
            for target in re.findall(r'[\"\']res://([^\"\']+)[\"\']', path.read_text()):
                if excluded(target):
                    raise ValueError(f'{path.relative_to(project)} depends on excluded export input {target}')


def validate_receipt(receipt, metadata, sources, app_files):
    if receipt['identity'] != metadata:
        raise ValueError('export identity/version is stale; export again')
    if receipt['source_files'] != sources:
        raise ValueError('production inputs changed after export; export again')
    if receipt['app_files'] != app_files:
        raise ValueError('exported app bytes changed; export again')
    if receipt['architecture'] != 'arm64':
        raise ValueError('receipt is not an arm64 export')


def prepare(project, engine):
    metadata = identity(project)
    validate_export_dependencies(project)
    dirty = subprocess.check_output(['git', '-C', str(project), 'status', '--porcelain',
                                     '--untracked-files=all', '--', *PRODUCTION], text=True)
    if dirty.strip():
        raise ValueError('commit production inputs before exporting:\n' + dirty)
    sources = production_files(project)
    receipt = {'identity': metadata, 'source_files': sources,
               'source_fingerprint': fingerprint(sources),
               'source_head': subprocess.check_output(['git', '-C', str(project), 'rev-parse', 'HEAD'], text=True).strip(),
               'engine': engine, 'source_kind': 'committed-production-export'}
    (project / 'build').mkdir(exist_ok=True)
    (project / 'build/export-source.json').write_text(json.dumps(receipt, indent=2) + '\n')


def finish(project):
    import plistlib
    receipt = json.loads((project / 'build/export-source.json').read_text())
    if receipt['identity'] != identity(project) or receipt['source_files'] != production_files(project):
        raise ValueError('production inputs changed during export')
    if receipt['source_head'] != subprocess.check_output(['git', '-C', str(project), 'rev-parse', 'HEAD'], text=True).strip():
        raise ValueError('Git HEAD changed during export')
    app = project / 'build' / receipt['identity']['app_name']
    plist = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    metadata = receipt['identity']
    if plist.get('CFBundleName') != metadata['name'] or plist.get('CFBundleDisplayName') != metadata['name']:
        raise ValueError('exported bundle name differs from project identity')
    if plist.get('LSArchitecturePriority') != ['arm64'] or set(plist.get('LSMinimumSystemVersionByArchitecture', {})) != {'arm64'}:
        raise ValueError('exported plist must advertise arm64 only')
    if (plist['CFBundleShortVersionString'], plist['CFBundleVersion'], plist['CFBundleIdentifier']) != (
            metadata['bundle_short_version'], metadata['bundle_build'], metadata['bundle_identifier']):
        raise ValueError('exported plist differs from project identity')
    executable = app / 'Contents/MacOS' / plist['CFBundleExecutable']
    packs = list((app / 'Contents/Resources').glob('*.pck'))
    if len(packs) != 1:
        raise ValueError('export must contain exactly one PCK')
    architecture = subprocess.check_output(['lipo', '-archs', str(executable)], text=True).strip()
    if architecture != 'arm64':
        raise ValueError('export executable must be arm64 only')
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    receipt.update({'architecture': architecture, 'executable': executable.relative_to(app).as_posix(),
                    'pck': packs[0].relative_to(app).as_posix(), 'app_files': inventory([app], app),
                    'executable_sha256': sha(executable), 'pck_sha256': sha(packs[0]),
                    'signature': 'ad-hoc; codesign --verify --deep --strict passed', 'notarized': False})
    (project / 'build/export-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'app': str(app), 'source_head': receipt['source_head'], 'architecture': architecture}))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['identity', 'prepare', 'finish'])
    parser.add_argument('--field')
    parser.add_argument('--engine')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[2]
    if args.mode == 'identity':
        metadata = identity(project)
        print(metadata[args.field] if args.field else json.dumps(metadata))
    elif args.mode == 'prepare':
        prepare(project, args.engine)
    else:
        finish(project)


if __name__ == '__main__':
    main()
