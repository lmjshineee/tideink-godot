"""Recheck the delivered source, protected inputs and actual application bytes."""
import json
from pathlib import Path
import re
import subprocess
import sys

EVIDENCE = Path(__file__).resolve().parent
PROJECT = EVIDENCE.parents[1]
sys.path.insert(0, str(PROJECT / 'tools/release'))
from build_metadata import identity, inventory, production_files, sha, validate_receipt

receipt = json.loads((PROJECT / 'build/export-receipt.json').read_text())
app = PROJECT / 'build' / receipt['identity']['app_name']
production = production_files(PROJECT)
validate_receipt(receipt, identity(PROJECT), production, inventory([app], app))
assert production == json.loads((EVIDENCE / 'export-production.json').read_text())
rule_inputs = json.loads((EVIDENCE / 'frozen-production.json').read_text())
assert set(production) == set(rule_inputs)
assert [name for name in production if production[name] != rule_inputs[name]] == ['src/ui/loadout_details.gd']
copy = json.loads((EVIDENCE / 'copy-only-ui.json').read_text())
old_text = subprocess.check_output(['git', '-C', str(PROJECT), 'show',
                                    copy['full_rules_head'] + ':src/ui/loadout_details.gd'], text=True)
for old, new in copy['replacements'].items(): old_text = old_text.replace(old, new)
assert old_text == (PROJECT / 'src/ui/loadout_details.gd').read_text()
assert 'PASS:' in (EVIDENCE / 'post-copy-parse.txt').read_text()
assert 'PASS:' in (EVIDENCE / 'post-copy-loadout.txt').read_text()
assert receipt['identity']['version'] == '0.3.0-preview.24'
assert receipt['architecture'] == 'arm64'
checks = (EVIDENCE / 'checks-committable.txt').read_text()
assert '通过 110，失败 0' in checks and '全部通过。' in checks

baseline = json.loads((EVIDENCE / 'starting-state.json').read_text())
protected = json.loads((EVIDENCE / 'protected-inputs.json').read_text())
for name, digest in baseline['assets'].items():
    if name != 'assets/integrity.json':
        assert sha(PROJECT / name) == digest, name
for name, digest in baseline['uids'].items():
    assert sha(PROJECT / protected['uid_renames'].get(name, name)) == digest, name
old_manifest = json.loads(subprocess.check_output(
    ['git', '-C', str(PROJECT), 'show', baseline['head'] + ':assets/integrity.json'], text=True))
manifest = json.loads((PROJECT / 'assets/integrity.json').read_text())
assert len(manifest['files']) == 274
assert all(manifest['files'][name] == value for name, value in old_manifest['files'].items())
assert len(set(manifest['files']) - set(old_manifest['files'])) == 4

backup = json.loads((PROJECT / 'build/export-receipt-preview.23.json').read_text())
backup_app = PROJECT / 'build/TideInk-preview.23.app'
assert inventory([backup_app], backup_app) == backup['app_files']
assert backup['pck_sha256'] != receipt['pck_sha256']

pack = json.loads((EVIDENCE / 'app-verification-final/verification.json').read_text())
assert pack['pck_sha256'] == receipt['pck_sha256']
assert len(pack['cases']) == 31 and all(case['status'] == 'passed' for case in pack['cases'])
for key in ['native', 'buddy_native', 'primary_native', 'loadout_native', 'attribute_native', 'art_native']:
    assert pack[key]['status'] == 'passed'
for name in ['native-fixed/attributes.json', 'app-verification-final/attribute-native/attributes.json',
             'app-verification-final/art-native/characters.json', 'natural-match/match.json']:
    assert json.loads((EVIDENCE / name).read_text())['status'] == 'passed', name

match = json.loads((EVIDENCE / 'natural-match/match.json').read_text())
assert len(match['attributes_at_start']) == 10
assert all(sum(value.values()) == 20 for value in match['attributes_at_start'].values())
assert match['completed_respawns'] > 0
metal = (EVIDENCE / 'standalone-metal.txt').read_text()
assert 'Metal' in metal and 'Apple M5' in metal
assert not re.search(r'^(ERROR:|SCRIPT ERROR:|WARNING:)', metal, re.M)
assert json.loads((EVIDENCE / 'app-open.json').read_text())['new_pids']

warning_logs = []
for folder in [EVIDENCE / 'source-rule-logs', EVIDENCE / 'app-verification-final']:
    for path in folder.rglob('*'):
        if path.suffix in ['.log', '.txt'] and '.engine.' not in path.name:
            lines = [line for line in path.read_text(errors='replace').splitlines() if line.startswith('WARNING:')]
            if lines: warning_logs.append({'file': str(path.relative_to(EVIDENCE)), 'warnings': lines})
export_warnings = [line for line in (EVIDENCE / 'export.txt').read_text().splitlines() if line.startswith('WARNING:')]
if export_warnings: warning_logs.append({'file': 'export.txt', 'warnings': export_warnings})
report = {
    'status': 'passed', 'version': receipt['identity']['version'],
    'source_head': receipt['source_head'], 'production_files': len(production),
    'source_fingerprint': receipt['source_fingerprint'], 'pck_sha256': receipt['pck_sha256'],
    'architecture': receipt['architecture'], 'signature': receipt['signature'],
    'source_checks': 110, 'exported_pck_rules': 31, 'native_pck_groups': 6,
    'full_rules_source_head': copy['full_rules_head'],
    'post_full_rules_change': 'Only two UI wording replacements; parse, loadout rules and actual PCK verification cover final copy.',
    'original_asset_files_preserved_except_intentional_manifest': len(baseline['assets']),
    'existing_uids_preserved': len(baseline['uids']), 'asset_manifest_entries': 274,
    'previous_app_backup_matches_receipt': True, 'headless_warning_logs': warning_logs,
    'human_balance_and_aesthetic_acceptance': False, 'thermal_acceptance': False,
}
(EVIDENCE / 'final-audit.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({key: value for key, value in report.items() if key != 'headless_warning_logs'}, ensure_ascii=False))
