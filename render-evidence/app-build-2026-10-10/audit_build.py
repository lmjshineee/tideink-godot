"""Check exact export bytes, production inputs and preserved local backups."""
import json
from pathlib import Path
import re
import sys
root = Path(__file__).resolve().parents[2]
base = Path(__file__).resolve().parent
sys.path.insert(0, str(root / 'tools/release'))
from build_metadata import identity, inventory, production_files, sha, validate_receipt
start = json.loads((base / 'starting-state.json').read_text())
receipt = json.loads((base / 'export-receipt.json').read_text())
assert json.loads((root / 'build/export-receipt.json').read_text()) == receipt
app = root / 'build/TideInk.app'
validate_receipt(receipt, identity(root), production_files(root), inventory([app], app))
assert receipt['source_head'] == start['source_head']
assert receipt['source_fingerprint'] == start['fingerprint']
assert production_files(root) == start['production_files']
assert inventory([root / 'assets'], root) == start['assets']
uids = {p.relative_to(root).as_posix(): sha(p) for p in sorted(root.rglob('*.uid'))
        if '.godot' not in p.parts and 'build' not in p.parts}
assert uids == start['uids']
backup = root / 'build/TideInk-preview.24.app'
backup_status = 'missing at final audit; matched seven-file inventory before and immediately after export'
if backup.exists():
    assert inventory([backup], backup) == start['old_app']['files']
    backup_status = 'unchanged'
backup_metadata = {}
for name, digest in start['preserved_backup_files'].items():
    path = root / 'build' / name
    backup_metadata[name] = 'missing' if not path.exists() else 'unchanged'
    if path.exists():
        assert sha(path) == digest
verification = json.loads((base / 'verification.json').read_text())
tactical = json.loads((base / 'tactical-and-metal.json').read_text())
for result in [verification, tactical]:
    assert result['status'] == 'passed'
    assert result['source_head'] == receipt['source_head']
    assert result['pck_sha256'] == receipt['pck_sha256']
assert len(verification['cases']) == 32
native_groups = ['native', 'buddy_native', 'primary_native', 'loadout_native', 'attribute_native', 'art_native']
assert all(verification[key]['status'] == 'passed' for key in native_groups)
warnings = {}
for case in verification['cases']:
    path = base / 'pack-verification' / (case['name'] + '.txt')
    lines = [line for line in path.read_text().splitlines() if line.startswith('WARNING:')]
    if lines:
        warnings[case['name']] = lines
ca_diagnostic = 'ERROR: Condition "ret != noErr" is true. Returning: ""'
export_diagnostics = {}
for name in ['import.log.txt', 'export.log.txt', 'export-smoke.log.txt']:
    lines = [line for line in (base / name).read_text().splitlines() if re.match(r'^(SCRIPT ERROR:|ERROR:|WARNING:)', line)]
    assert all(line == ca_diagnostic for line in lines)
    export_diagnostics[name] = lines
result = {'status': 'passed', 'source_head': receipt['source_head'], 'source_fingerprint': receipt['source_fingerprint'],
          'production_files': len(receipt['source_files']), 'architecture': receipt['architecture'],
          'signature': receipt['signature'], 'pck_sha256': receipt['pck_sha256'], 'app_files': len(receipt['app_files']),
          'source_regression_reused': start['reused_source_regression'], 'actual_pck_rules': 32,
          'actual_pck_warning_cases': warnings, 'native_groups': native_groups, 'tactical_images': tactical['tactical']['images'],
          'export_known_system_ca_diagnostics': export_diagnostics,
          'assets_preserved': len(start['assets']), 'uids_preserved': len(start['uids']),
          'old_backup_source_head': start['old_app']['source_head'], 'old_backup_status': backup_status,
          'old_backup_metadata': backup_metadata,
          'versions_unchanged': receipt['identity'] == start['identity'],
          'natural_match_retested': False, 'human_aesthetic_acceptance': False, 'thermal_retested': False}
(base / 'audit.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({k: result[k] for k in ['status', 'source_head', 'production_files', 'actual_pck_rules', 'assets_preserved', 'uids_preserved', 'versions_unchanged']}))
