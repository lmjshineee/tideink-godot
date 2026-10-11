"""Continue only unfinished native groups on the exact already-checked App/PCK."""
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

PROJECT = Path(__file__).resolve().parents[2]
EVIDENCE = Path(__file__).resolve().parent
sys.path.insert(0, str(PROJECT / 'tools/release'))
from build_metadata import identity, inventory, production_files, sha, validate_receipt
from verify_app import run, CASES

receipt = json.loads((PROJECT / 'build/export-receipt.json').read_text())
app = PROJECT / 'build/TideInk.app'
validate_receipt(receipt, identity(PROJECT), production_files(PROJECT), inventory([app], app))
first_log = (EVIDENCE / 'pack-verification.txt').read_text()
assert all('PASS exported PCK: ' + name + '\n' in first_log for name in CASES)
assert len(CASES) == 34
report = {
    'source_head': receipt['source_head'], 'pck_sha256': receipt['pck_sha256'],
    'production_inputs_unchanged': True, 'status': 'running',
    'prior': {'rules_passed': 34, 'native_passed': ['native', 'buddy-native', 'primary-native'],
              'log': 'pack-verification.txt', 'failed_fixture': 'exported-pack/loadout-native.txt',
              'note': 'The first aggregate stopped before emitting its report. Its stdout/engine logs and committed verifier remain. Exact deleted temporary fixture hashes from that run are unavailable.'},
    'loadout_followup': json.loads((EVIDENCE / 'loadout-followup-fixture.json').read_text()),
    'groups': {},
}
for name in report['prior']['native_passed']:
    text = (EVIDENCE / 'exported-pack' / (name + '.txt')).read_text()
    assert re.search(r'^PASS:', text, re.M)
    assert not re.search(r'^(?:ERROR:|SCRIPT ERROR:|FAIL:)', text, re.M)
assert json.loads((EVIDENCE / 'loadout-followup/loadout.json').read_text())['status'] == 'passed'

def save():
    (EVIDENCE / 'remaining-verification.json').write_text(json.dumps(report, indent=2) + '\n')

fixture = Path('/private/tmp/tideink-followup-6747da7')
assert fixture.is_dir()
common = ['/Applications/Godot.app/Contents/MacOS/Godot', '--main-pack', str(app / receipt['pck'])]
specs = (
    ('attributes', 'verify_attribute_allocation.gd', '\troot.size='),
    ('art', 'capture_archetypes.gd', '\troot.size='),
    ('wardrobe', 'verify_wardrobe.gd', None),
    ('curated', 'verify_curated_art.gd', '\tSetup.pending_loadout='),
)
save()
for name, filename, end_marker in specs:
    source = PROJECT / 'tools/capture' / filename
    text = source.read_text().replace('res://tests/godot/helpers/creative_fixture.gd', str(fixture / 'creative_fixture.gd'))
    if end_marker:
        start = text.index('\treport.source_sha256={}')
        end = text.index(end_marker, start)
        text = text[:start] + '\treport.verification="explicit unchanged exported PCK; receipt supplies pack identity"\n' + text[end:]
    external = fixture / (name + '-native.gd')
    external.write_text(text)
    run(common + ['--rendering-driver', 'metal', '--script', str(external),
                  '--log-file', str(EVIDENCE / (name + '-followup.engine.txt')), '--',
                  '--output=' + str(EVIDENCE / (name + '-followup'))],
        fixture, EVIDENCE / (name + '-followup.txt'))
    report['groups'][name] = {'status': 'passed', 'source_sha256': sha(source),
                             'external_sha256': sha(external), 'pck_sha256': receipt['pck_sha256']}
    save()
    print('PASS native follow-up:', name, flush=True)

for name, options, timeout in [
    ('app-headless', ['--headless', '--quit-after', '4'], 30),
    ('app-metal', ['--rendering-driver', 'metal', '--quit-after', '90'], 60),
]:
    log = EVIDENCE / (name + '.txt')
    with log.open('w') as output:
        result = subprocess.run([str(app / receipt['executable']), *options,
                                 '--log-file', str(EVIDENCE / (name + '.engine.txt'))],
                                cwd=fixture, stdout=output, stderr=subprocess.STDOUT, timeout=timeout)
    text = log.read_text()
    assert result.returncode == 0 and not re.search(r'^(?:ERROR:|SCRIPT ERROR:)', text, re.M), text
    report['groups'][name] = {'status': 'passed', 'exit': result.returncode,
                             'path_overrides': False, 'script_overrides': False}
    save()
    print('PASS actual App startup:', name, flush=True)

validate_receipt(receipt, identity(PROJECT), production_files(PROJECT), inventory([app], app))
report['status'] = 'passed'
report['native_groups_passed'] = 8
report['actual_app_startup_passed'] = ['headless', 'Metal']
save()
print('PASS: 34 retained PCK rules, eight native groups, actual App startup and final receipt', flush=True)
