"""Check the new tactical cards and actual Metal app against this export receipt."""
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[2]
output = Path(__file__).resolve().parent
sys.path.insert(0, str(root / 'tools/release'))
from build_metadata import identity, inventory, production_files, sha, validate_receipt
from verify_app import run

receipt = json.loads((output / 'export-receipt.json').read_text())
app = root / 'build/TideInk.app'
validate_receipt(receipt, identity(root), production_files(root), inventory([app], app))
engine = '/Applications/Godot.app/Contents/MacOS/Godot'
assert subprocess.check_output([engine, '--version'], text=True).strip() == receipt['engine']
transform = json.loads((output / 'tactical-fixture-transform.json').read_text())
script = output / 'tactical-fixtures/check_bot_attribute_builds.gd'
assert sha(script) == transform['external_sha256']
assert sha(root / 'tests/godot/check_bot_attribute_builds.gd') == transform['source_sha256']
with tempfile.TemporaryDirectory(prefix='tideink-tactical-pack-') as temporary:
    cwd = Path(temporary)
    run([engine, '--main-pack', str(app / receipt['pck']), '--rendering-driver', 'metal',
         '--script', str(script), '--log-file', str(output / 'tactical-native.engine.txt'),
         '--', '--output=' + str(output / 'tactical-native')], cwd, output / 'tactical-native.txt')
    capture = json.loads((output / 'tactical-native/bot-builds.json').read_text())
    assert capture['status'] == 'passed' and capture['environment']['arm64']
    assert len(capture['images']) == 4
    assert not re.search(r'^(SCRIPT ERROR:|ERROR:|WARNING:)', (output / 'tactical-native.txt').read_text(), re.M)
    with (output / 'app-metal.txt').open('w') as log:
        metal = subprocess.run([str(app / receipt['executable']), '--rendering-driver', 'metal',
                                '--quit-after', '90', '--log-file', str(output / 'app-metal.engine.txt')],
                               cwd=cwd, stdout=log, stderr=subprocess.STDOUT, timeout=30)
    assert metal.returncode == 0
    assert not re.search(r'^(SCRIPT ERROR:|ERROR:|WARNING:)', (output / 'app-metal.txt').read_text(), re.M)
validate_receipt(receipt, identity(root), production_files(root), inventory([app], app))
report = {'status': 'passed', 'source_head': receipt['source_head'], 'pck_sha256': receipt['pck_sha256'],
          'tactical': {'images': capture['images'], 'environment': capture['environment'],
                       'fixture': transform, 'working_directory': 'temporary outside checkout',
                       'method': 'Explicit PCK; external test only; real Tab down/up events, two sizes and 1v1/5v5.'},
          'actual_app_metal': {'exit': metal.returncode, 'frames': 90, 'path_overrides': False,
                               'script_overrides': False, 'pack_overrides': False,
                               'working_directory': 'temporary outside checkout'},
          'human_aesthetic_acceptance': False, 'natural_match_retested': False, 'thermal_retested': False}
(output / 'tactical-and-metal.json').write_text(json.dumps(report, indent=2) + '\n')
print('PASS: four actual PCK tactical captures and native Metal application startup outside checkout')
