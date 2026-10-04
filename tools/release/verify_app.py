#!/usr/bin/env python3
"""Run external fixtures against the actual exported app/PCK, outside the checkout."""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

from build_metadata import identity, inventory, production_files, sha, validate_receipt

CA_NOISE = 'ERROR: Condition "ret != noErr" is true. Returning: ""'
CASES = ('check_tidewater_turf_points', 'check_gameplay_deployment', 'check_expanded_loadouts',
         'check_bow_precision', 'check_canopy_push', 'check_creative_wings',
         'check_vertical_combat', 'check_actor_turf_credit')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True, help='New evidence subdirectory')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[2]
    output = (project / args.output).resolve()
    if (project / 'render-evidence').resolve() not in output.parents or output.exists():
        raise ValueError('use a new render-evidence subdirectory')
    receipt = json.loads((project / 'build/export-receipt.json').read_text())
    app = project / 'build' / receipt['identity']['app_name']
    validate_receipt(receipt, identity(project), production_files(project), inventory([app], app))
    output.mkdir(parents=True)
    report = {'source_head': receipt['source_head'], 'pck_sha256': receipt['pck_sha256'],
              'method': 'External fixtures; explicit exported PCK; working directory is a temporary directory, not the checkout.',
              'cases': [], 'native': None}
    with tempfile.TemporaryDirectory(prefix='tideink-pck-') as temp:
        fixture = Path(temp)
        shutil.copy2(project / 'tests/godot/helpers/creative_fixture.gd', fixture / 'creative_fixture.gd')
        common = [str(app / receipt['executable']), '--main-pack', str(app / receipt['pck'])]
        for name in CASES:
            source = project / 'tests/godot' / (name + '.gd')
            script = fixture / source.name
            script.write_text(source.read_text().replace('res://tests/godot/helpers/creative_fixture.gd',
                                                       str(fixture / 'creative_fixture.gd')))
            run(common + ['--headless', '--script', str(script), '--log-file', str(output / (name + '.engine.txt'))],
                fixture, output / (name + '.txt'))
            report['cases'].append({'name': name, 'source_sha256': sha(source), 'external_sha256': sha(script), 'status': 'passed'})
            print('PASS exported PCK:', name, flush=True)
        native = fixture / 'native.gd'
        shutil.copy2(project / 'tools/capture/verify_release_ui.gd', native)
        run(common + ['--rendering-driver', 'metal', '--script', str(native),
                      '--log-file', str(output / 'native.engine.txt'), '--',
                      '--require-pack', '--output=' + str(output / 'native')], fixture, output / 'native.txt')
        report['native'] = {'status': 'passed', 'fixture_sha256': sha(native)}
    (output / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print('PASS: eight exported PCK rules and native app verification')


def run(command, cwd, output):
    with output.open('w') as log:
        result = subprocess.run(command, cwd=cwd, stdout=log, stderr=subprocess.STDOUT, timeout=120)
    text = output.read_text()
    errors = [line for line in text.splitlines() if re.match(r'^(SCRIPT ERROR:|ERROR:|FAIL:)', line) and line != CA_NOISE]
    if result.returncode != 0 or not re.search(r'^PASS:', text, re.M) or errors:
        raise RuntimeError(f'export verification failed: {output}; exit={result.returncode}; {errors[:3]}')


if __name__ == '__main__':
    main()
