"""Complete the interrupted aggregate without repeating already passed fixtures."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

EVIDENCE = Path(__file__).resolve().parent
PROJECT = EVIDENCE.parent.parent
sys.path.insert(0, str(PROJECT / 'tools/release'))
from build_metadata import identity, inventory, production_files, sha, validate_receipt
from verify_app import CASES, CA_NOISE


def passed_log(path):
    text = path.read_text()
    errors = [line for line in text.splitlines()
              if re.match(r'^(SCRIPT ERROR:|ERROR:|FAIL:)', line) and line != CA_NOISE]
    assert re.search(r'^PASS:', text, re.M) and not errors, (path, errors)
    return [line for line in text.splitlines() if line.startswith('WARNING:')]


receipt = json.loads((PROJECT / 'build/export-receipt.json').read_text())
app = PROJECT / 'build' / receipt['identity']['app_name']
validate_receipt(receipt, identity(PROJECT), production_files(PROJECT), inventory([app], app))
report = {'source_head': receipt['source_head'], 'pck_sha256': receipt['pck_sha256'],
          'method': 'Initial verify_app.py completed 33 explicit-PCK rules and six native groups. '
                    'Its seventh group failed a hover assertion after screenshot cursor motion. '
                    'Only that fixture was corrected and independently rerun against the same PCK. '
                    'This continuation verifies unchanged fixture sources/logs, performs actual App startup '
                    'outside the project, and rechecks source/App receipt identity.',
          'initial_aggregate_exit': 1, 'cases': [], 'native': {}}
initial = EVIDENCE / 'pack-verification'


def unchanged_source(relative):
    path = PROJECT / relative
    committed = subprocess.check_output(['git', '-C', str(PROJECT), 'show', receipt['source_head'] + ':' + relative])
    assert hashlib.sha256(committed).hexdigest() == sha(path), relative
    return sha(path)


unchanged_source('tools/release/verify_app.py')
for case in CASES:
    relative = 'tests/godot/' + case + '.gd'
    report['cases'].append({'name': case, 'status': 'passed',
                            'source_sha256': unchanged_source(relative),
                            'warnings': passed_log(initial / (case + '.txt'))})
for name, script in [('native', 'verify_release_ui'), ('buddy-native', 'verify_ink_buddy'),
                     ('primary-native', 'verify_primary_combat'), ('loadout-native', 'verify_loadout_tuning'),
                     ('attribute-native', 'verify_attribute_allocation'), ('art-native', 'capture_archetypes')]:
    relative = 'tools/capture/' + script + '.gd'
    report['native'][name] = {'status': 'passed', 'source_sha256': unchanged_source(relative),
                              'warnings': passed_log(initial / (name + '.txt'))}
wardrobe = json.loads((EVIDENCE / 'wardrobe-native-fixed/native.json').read_text())
assert wardrobe['status'] == 'passed' and len(wardrobe['cases']) == 2
source = PROJECT / 'tools/capture/verify_wardrobe.gd'
assert sha(source) == sha('/private/tmp/tideink-wardrobe-final.gd')
report['native']['wardrobe-native-fixed'] = {
    'status': 'passed', 'source_sha256': sha(source), 'cases': wardrobe['cases'],
    'warnings': passed_log(EVIDENCE / 'wardrobe-native-fixed.txt')}
output = EVIDENCE / 'app-startup-final'
output.mkdir()
for name, flags in [('headless', ['--headless', '--quit-after', '4']),
                    ('metal', ['--rendering-driver', 'metal', '--quit-after', '90'])]:
    command = [str(app / receipt['executable']), *flags, '--log-file', str(output / (name + '.engine.txt'))]
    with (output / (name + '.txt')).open('w') as log:
        result = subprocess.run(command, cwd='/private/tmp', stdout=log, stderr=subprocess.STDOUT, timeout=60)
    text = (output / (name + '.txt')).read_text()
    assert result.returncode == 0 and not re.search(r'^(SCRIPT ERROR:|ERROR:)', text, re.M), name
    report['app_' + name] = {'exit': result.returncode, 'path_overrides': False,
                             'script_overrides': False, 'command': command,
                             'warnings': [line for line in text.splitlines() if line.startswith('WARNING:')]}
validate_receipt(receipt, identity(PROJECT), production_files(PROJECT), inventory([app], app))
report['status'] = 'passed'
(EVIDENCE / 'pack-verification-completed.json').write_text(json.dumps(report, indent=2) + '\n')
print('PASS: 33 actual PCK rules, seven native groups, actual App headless/Metal startup; receipt unchanged')
