#!/usr/bin/env python3
"""Isolation tests for stale exports, changed app bytes and false source labels."""
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/release'))
from build_metadata import identity, inventory, production_files, fingerprint
from package_macos import validate_release, evidence_paths


class ReleaseIntegrity(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='tideink-release-test-')
        self.root = Path(self.temp.name).resolve()
        (self.root / 'project.godot').write_text('; Engine configuration\nconfig_version=5\n\n[application]\nconfig/name="TideInk"\nconfig/version="0.3.0-preview.16"\n')
        (self.root / 'export_presets.cfg').write_text('''[preset.0]
export_path="build/TideInk.app"
[preset.0.options]
application/short_version="0.3.0"
application/version="0.3.16"
application/bundle_identifier="com.yunni.tideink"
binary_format/architecture="arm64"
''')
        (self.root / 'src').mkdir()
        (self.root / 'src/play.gd').write_text('extends Node\n')
        self.app = self.root / 'build/TideInk.app'
        self.app.mkdir(parents=True)
        (self.app / 'game.pck').write_bytes(b'exported contents')
        self.metadata = identity(self.root)
        self.sources = production_files(self.root)
        self.app_files = inventory([self.app], self.app)
        self.receipt = {'identity': self.metadata, 'source_files': self.sources,
                        'app_files': self.app_files, 'architecture': 'arm64',
                        'source_head': 'a' * 40}
        self.addCleanup(self.temp.cleanup)

    def validate(self, **changes):
        values = {'receipt': self.receipt, 'metadata': identity(self.root),
                  'sources': production_files(self.root), 'app_files': inventory([self.app], self.app),
                  'version': 'v0.3.0-preview.16'}
        values.update(changes)
        validate_release(**values)

    def test_current_export_and_actual_source_override(self):
        self.validate(source_commit='a' * 40)

    def test_changed_source_rejected(self):
        (self.root / 'src/play.gd').write_text('extends Node3D\n')
        with self.assertRaisesRegex(ValueError, 'production inputs changed'):
            self.validate()

    def test_changed_pack_rejected(self):
        (self.app / 'game.pck').write_bytes(b'old or modified app')
        with self.assertRaisesRegex(ValueError, 'app bytes changed'):
            self.validate()

    def test_added_app_file_rejected(self):
        (self.app / 'unexpected.import').write_text('must also be hashed')
        with self.assertRaisesRegex(ValueError, 'app bytes changed'):
            self.validate()

    def test_wrong_tag_and_false_commit_rejected(self):
        with self.assertRaisesRegex(ValueError, 'tag differs'):
            self.validate(version='v0.3.0-preview.15')
        with self.assertRaisesRegex(ValueError, 'actual export receipt'):
            self.validate(source_commit='b' * 40)

    def test_stale_identity_rejected(self):
        with self.assertRaisesRegex(ValueError, 'identity/version is stale'):
            self.validate(metadata=dict(self.metadata, version='0.3.0-preview.17'))

    def test_architecture_rejected(self):
        with self.assertRaisesRegex(ValueError, 'not an arm64'):
            self.validate(receipt=dict(self.receipt, architecture='invalid'))

    def test_identity_must_agree_with_export_preset(self):
        path = self.root / 'export_presets.cfg'
        text = path.read_text()
        for old, new in [('build/TideInk.app', 'build/Old.app'), ('"0.3.0"', '"0.2.0"'), ('"arm64"', '"invalid"')]:
            path.write_text(text.replace(old, new))
            with self.subTest(old=old), self.assertRaises(ValueError):
                identity(self.root)
        path.write_text(text)

    def test_evidence_path_cannot_escape(self):
        directory = self.root / 'render-evidence/batch'
        directory.mkdir(parents=True)
        self.assertEqual(evidence_paths(self.root, ['render-evidence/batch']), [directory])
        with self.assertRaises(ValueError):
            evidence_paths(self.root, ['src'])
        with self.assertRaises(ValueError):
            evidence_paths(self.root, ['render-evidence/batch', 'render-evidence/batch'])

    def test_fingerprint_covers_added_source_and_import_settings(self):
        before = fingerprint(production_files(self.root))
        (self.root / 'src/generated.import').write_text('import configuration')
        self.assertNotEqual(before, fingerprint(production_files(self.root)))
        before = fingerprint(production_files(self.root))
        (self.root / 'src/new.gd').write_text('extends Node\n')
        self.assertNotEqual(before, fingerprint(production_files(self.root)))


if __name__ == '__main__':
    unittest.main(verbosity=2)
