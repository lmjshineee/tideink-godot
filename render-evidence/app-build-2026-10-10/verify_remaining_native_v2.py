"""Resume this export's native checks without repeating its 32 passed pack rules."""
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
root = Path(__file__).resolve().parents[2]
base = Path(__file__).resolve().parent
output = base / 'remaining-native-2'
assert not output.exists()
sys.path.insert(0, str(root / 'tools/release'))
from build_metadata import identity, inventory, production_files, sha, validate_receipt
from verify_app import CASES, run
receipt = json.loads((base / 'export-receipt.json').read_text())
app = root / 'build/TideInk.app'
validate_receipt(receipt, identity(root), production_files(root), inventory([app], app))
engine = '/Applications/Godot.app/Contents/MacOS/Godot'
assert subprocess.check_output([engine, '--version'], text=True).strip() == receipt['engine']
previous = base / 'pack-verification'
outer = (base / 'verify-app.txt').read_text()
report = {'source_head': receipt['source_head'], 'pck_sha256': receipt['pck_sha256'], 'cases': [],
          'preserved_initial_failure': 'pack-verification/primary-native.txt',
          'method': 'Reuse the 32 successful rules and two successful native groups from the same unchanged PCK; run the corrected primary fixture and remaining native groups outside the checkout.'}
for name in CASES:
    log = previous / (name + '.txt')
    assert 'PASS exported PCK: ' + name in outer
    assert re.search(r'^PASS:', log.read_text(), re.M)
    assert not re.search(r'^(SCRIPT ERROR:|ERROR:|FAIL:)', log.read_text(), re.M)
    report['cases'].append({'name': name, 'status': 'passed', 'stdout_sha256': sha(log),
                            'source_sha256': sha(root / 'tests/godot' / (name + '.gd')), 'reused': True})
for kind, source in [('native', 'verify_release_ui.gd'), ('buddy_native', 'verify_ink_buddy.gd')]:
    log = previous / ('native.txt' if kind == 'native' else 'buddy-native.txt')
    assert re.search(r'^PASS:', log.read_text(), re.M)
    assert not re.search(r'^(SCRIPT ERROR:|ERROR:|FAIL:|WARNING:)', log.read_text(), re.M)
    report[kind] = {'status': 'passed', 'stdout_sha256': sha(log),
                     'source_sha256': sha(root / 'tools/capture' / source), 'reused': True}
output.mkdir()
fixtures = base / 'remaining-fixtures-2'
fixtures.mkdir()
shutil.copy2(root / 'tests/godot/helpers/creative_fixture.gd', fixtures / 'creative_fixture.gd')
def external_test(text):
    return text.replace('res://tests/godot/helpers/creative_fixture.gd', str(fixtures / 'creative_fixture.gd')).replace(
        'res://tests/godot/check_damage_contract.gd', str(fixtures / 'check_damage_contract.gd'))
(fixtures / 'check_damage_contract.gd').write_text(external_test((root / 'tests/godot/check_damage_contract.gd').read_text()))
with tempfile.TemporaryDirectory(prefix='tideink-resume-pack-') as temporary:
    cwd = Path(temporary)
    common = [engine, '--main-pack', str(app / receipt['pck'])]
    for kind, basename in [('primary', 'verify_primary_combat.gd'), ('loadout', 'verify_loadout_tuning.gd'),
                           ('attribute', 'verify_attribute_allocation.gd'), ('art', 'capture_archetypes.gd')]:
        source = root / 'tools/capture' / basename
        external = external_test(source.read_text())
        if kind == 'primary':
            begin = external.index('\tvar paths: Array[String] = ')
            end = external.index('\tawait super._run()', begin)
        elif kind in ('loadout', 'attribute'):
            begin = external.index('\treport.source_sha256={}')
            end = external.index('\troot.size=', begin)
        if kind != 'art':
            variable = 'native_report' if kind == 'primary' else 'report'
            external = external[:begin] + '\t' + variable + '.verification="explicit exported PCK; receipt supplies pack identity"\n' + (
                '\tif ProjectSettings.get_setting("application/config/version") != ' + json.dumps(receipt['identity']['version']) + ':\n'
                '\t\tprinterr("FAIL: wrong exported version");quit(1);return\n') + external[end:]
        script = fixtures / (kind + '.gd')
        script.write_text(external)
        run(common + ['--rendering-driver', 'metal', '--script', str(script),
                      '--log-file', str(output / (kind + '.engine.txt')), '--',
                      '--output=' + str(output / kind)], cwd, output / (kind + '.txt'))
        assert not re.search(r'^(SCRIPT ERROR:|ERROR:|WARNING:)', (output / (kind + '.txt')).read_text(), re.M)
        report[kind + '_native'] = {'status': 'passed', 'source_sha256': sha(source), 'external_sha256': sha(script),
                                    'pck_sha256': receipt['pck_sha256'], 'reused': False}
        print('PASS exported PCK native:', kind, flush=True)
        (base / 'verification-checkpoint-2.json').write_text(json.dumps(report, indent=2) + '\n')
    with (output / 'app-startup.txt').open('w') as log:
        result = subprocess.run([str(app / receipt['executable']), '--headless', '--quit-after', '4',
                                 '--log-file', str(output / 'app-startup.engine.txt')],
                                cwd=cwd, stdout=log, stderr=subprocess.STDOUT, timeout=30)
    assert result.returncode == 0
    assert not re.search(r'^(SCRIPT ERROR:|ERROR:|WARNING:)', (output / 'app-startup.txt').read_text(), re.M)
    report['app_startup'] = {'exit': result.returncode, 'path_overrides': False, 'script_overrides': False,
                             'pack_overrides': False, 'working_directory': 'temporary outside checkout'}
validate_receipt(receipt, identity(root), production_files(root), inventory([app], app))
report['status'] = 'passed'
(base / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
print('PASS: 32 exported PCK rules, six native input/art groups and actual application headless startup')
