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
         'check_vertical_combat', 'check_actor_turf_credit',
         'check_bot_high_ground', 'check_experience_balance',
         'check_weapon_specials', 'check_combat_readability', 'check_ink_hazard_feedback',
         'check_bot_patrol_commitment', 'check_bot_route_clearance',
         'check_bot_map_platforms', 'check_team_navigation_motion', 'check_map_routes26',
         'check_bot_beacon_placement', 'check_ink_buddy_combat', 'check_ink_buddy_lifecycle', 'check_item_previews',
         'check_damage_contract', 'check_damage_regions', 'check_bot_ink_refill',
         'check_roller_surface_contact', 'check_extended_damage', 'check_loadout_tuning', 'check_area_rules', 'check_attribute_allocation', 'check_bot_attribute_builds', 'check_character_archetypes')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True, help='New evidence subdirectory')
    parser.add_argument('--godot', default='/Applications/Godot.app/Contents/MacOS/Godot', help='Matching native editor executable for PCK fixtures')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[2]
    output = (project / args.output).resolve()
    if (project / 'render-evidence').resolve() not in output.parents or output.exists():
        raise ValueError('use a new render-evidence subdirectory')
    receipt = json.loads((project / 'build/export-receipt.json').read_text())
    app = project / 'build' / receipt['identity']['app_name']
    validate_receipt(receipt, identity(project), production_files(project), inventory([app], app))
    output.mkdir(parents=True)
    if subprocess.check_output([args.godot, '--version'], text=True).strip() != receipt['engine']:
        raise ValueError('PCK verification engine differs from export engine')
    report = {'source_head': receipt['source_head'], 'pck_sha256': receipt['pck_sha256'],
              'method': 'Matching native Godot editor loads the explicit exported PCK for external rule/UI fixtures. Working directory is temporary. Actual app startup is separately checked without path/script overrides.',
              'cases': [], 'native': None}
    with tempfile.TemporaryDirectory(prefix='tideink-pck-') as temp:
        fixture = Path(temp)
        shutil.copy2(project / 'tests/godot/helpers/creative_fixture.gd', fixture / 'creative_fixture.gd')
        def external_test(text):
            return text.replace('res://tests/godot/helpers/creative_fixture.gd',
                                str(fixture / 'creative_fixture.gd')).replace(
                                    'res://tests/godot/check_damage_contract.gd',
                                    str(fixture / 'check_damage_contract.gd'))
        # A test inherited by the extension and native probe is also external.
        parent = project / 'tests/godot/check_damage_contract.gd'
        (fixture / parent.name).write_text(external_test(parent.read_text()))
        common = [args.godot, '--main-pack', str(app / receipt['pck'])]
        for name in CASES:
            source = project / 'tests/godot' / (name + '.gd')
            script = fixture / source.name
            script.write_text(external_test(source.read_text()))
            run(common + ['--headless', '--script', str(script), '--log-file', str(output / (name + '.engine.txt'))],
                fixture, output / (name + '.txt'))
            report['cases'].append({'name': name, 'source_sha256': sha(source), 'external_sha256': sha(script), 'status': 'passed'})
            print('PASS exported PCK:', name, flush=True)
        native = fixture / 'native.gd'
        shutil.copy2(project / 'tools/capture/verify_release_ui.gd', native)
        run(common + ['--rendering-driver', 'metal', '--script', str(native),
                      '--log-file', str(output / 'native.engine.txt'), '--',
                      '--require-pack', '--expected-version=' + receipt['identity']['version'],
                      '--output=' + str(output / 'native')], fixture, output / 'native.txt')
        report['native'] = {'status': 'passed', 'fixture_sha256': sha(native)}
        buddy_source = project / 'tools/capture/verify_ink_buddy.gd'
        buddy = fixture / 'buddy_native.gd'
        # Tools are excluded from production PCKs. The enclosing receipt supplies
        # the pack identity; remove only the source-only inventory dependency.
        original = buddy_source.read_text()
        external = original.replace('res://tests/godot/helpers/creative_fixture.gd',
                                    str(fixture / 'creative_fixture.gd'))
        external = external.replace('const Inventory:=preload("res://tools/lib/source_inventory.gd")\n', '')
        begin = external.index('\treport.source_sha256={}\n')
        end = external.index('\tfor actor in game.all_actors():', begin)
        external = external[:begin] + '\treport.verification="explicit exported PCK; receipt supplies pack identity"\n' + external[end:]
        buddy.write_text(external)
        run(common + ['--rendering-driver', 'metal', '--script', str(buddy),
                      '--log-file', str(output / 'buddy-native.engine.txt'), '--',
                      '--output=' + str(output / 'buddy-native')], fixture, output / 'buddy-native.txt')
        report['buddy_native'] = {'status': 'passed', 'source_sha256': sha(buddy_source),
                                  'external_sha256': sha(buddy), 'pck_sha256': receipt['pck_sha256']}
        primary_source = project / 'tools/capture/verify_primary_combat.gd'
        primary = fixture / 'primary_native.gd'
        external = external_test(primary_source.read_text())
        begin = external.index('\tvar paths: Array[String] = ')
        end = external.index('\tawait super._run()', begin)
        external = external[:begin] + (
            '\tnative_report.verification="explicit exported PCK; receipt supplies pack identity"\n'
            '\tif ProjectSettings.get_setting("application/config/version") != '
            + json.dumps(receipt['identity']['version']) + ':\n'
            '\t\tprinterr("FAIL: wrong exported version");quit(1);return\n'
        ) + external[end:]
        primary.write_text(external)
        run(common + ['--rendering-driver', 'metal', '--script', str(primary),
                      '--log-file', str(output / 'primary-native.engine.txt'), '--',
                      '--output=' + str(output / 'primary-native')], fixture, output / 'primary-native.txt')
        report['primary_native'] = {'status': 'passed', 'source_sha256': sha(primary_source),
                                    'external_sha256': sha(primary), 'pck_sha256': receipt['pck_sha256']}
        loadout_source = project / 'tools/capture/verify_loadout_tuning.gd'
        loadout = fixture / 'loadout_native.gd'
        external = external_test(loadout_source.read_text())
        begin = external.index('\treport.source_sha256={}')
        end = external.index('\troot.size=', begin)
        external = external[:begin] + (
            '\treport.verification="explicit exported PCK; receipt supplies pack identity"\n'
            '\tif ProjectSettings.get_setting("application/config/version") != '
            + json.dumps(receipt['identity']['version']) + ':\n'
            '\t\tprinterr("FAIL: wrong exported version");quit(1);return\n'
        ) + external[end:]
        loadout.write_text(external)
        run(common + ['--rendering-driver', 'metal', '--script', str(loadout),
                      '--log-file', str(output / 'loadout-native.engine.txt'), '--',
                      '--output=' + str(output / 'loadout-native')], fixture, output / 'loadout-native.txt')
        report['loadout_native'] = {'status': 'passed', 'source_sha256': sha(loadout_source),
                                    'external_sha256': sha(loadout), 'pck_sha256': receipt['pck_sha256']}
        attribute_source = project / 'tools/capture/verify_attribute_allocation.gd'
        attributes = fixture / 'attribute_native.gd'
        external = external_test(attribute_source.read_text())
        begin = external.index('\treport.source_sha256={}')
        end = external.index('\troot.size=', begin)
        external = external[:begin] + (
            '\treport.verification="explicit exported PCK; receipt supplies pack identity"\n'
            '\tif ProjectSettings.get_setting("application/config/version") != '
            + json.dumps(receipt['identity']['version']) + ':\n'
            '\t\tprinterr("FAIL: wrong exported version");quit(1);return\n'
        ) + external[end:]
        attributes.write_text(external)
        run(common + ['--rendering-driver', 'metal', '--script', str(attributes),
                      '--log-file', str(output / 'attribute-native.engine.txt'), '--',
                      '--output=' + str(output / 'attribute-native')], fixture, output / 'attribute-native.txt')
        report['attribute_native'] = {'status': 'passed', 'source_sha256': sha(attribute_source),
                                'external_sha256': sha(attributes), 'pck_sha256': receipt['pck_sha256']}
        art_source = project / 'tools/capture/capture_archetypes.gd'
        art = fixture / 'art_native.gd'
        shutil.copy2(art_source, art)
        run(common + ['--rendering-driver', 'metal', '--script', str(art),
                      '--log-file', str(output / 'art-native.engine.txt'), '--',
                      '--output=' + str(output / 'art-native')], fixture, output / 'art-native.txt')
        report['art_native'] = {'status': 'passed', 'source_sha256': sha(art_source),
                               'external_sha256': sha(art), 'pck_sha256': receipt['pck_sha256']}
        smoke = output / 'app-startup.txt'
        with smoke.open('w') as log:
            result = subprocess.run([str(app / receipt['executable']), '--headless', '--quit-after', '4',
                                     '--log-file', str(output / 'app-startup.engine.txt')],
                                    cwd=fixture, stdout=log, stderr=subprocess.STDOUT, timeout=30)
        if result.returncode != 0 or re.search(r'^(SCRIPT ERROR:|ERROR:)', smoke.read_text(), re.M):
            raise RuntimeError('actual app startup failed; see ' + str(smoke))
        report['app_startup'] = {'exit': result.returncode, 'path_overrides': False, 'script_overrides': False}
    (output / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'PASS: {len(CASES)} exported PCK rules, six native PCK input/art groups and actual app startup')


def run(command, cwd, output):
    with output.open('w') as log:
        result = subprocess.run(command, cwd=cwd, stdout=log, stderr=subprocess.STDOUT, timeout=120)
    text = output.read_text()
    errors = [line for line in text.splitlines() if re.match(r'^(SCRIPT ERROR:|ERROR:|FAIL:)', line) and line != CA_NOISE]
    if result.returncode != 0 or not re.search(r'^PASS:', text, re.M) or errors:
        raise RuntimeError(f'export verification failed: {output}; exit={result.returncode}; {errors[:3]}')


if __name__ == '__main__':
    main()
