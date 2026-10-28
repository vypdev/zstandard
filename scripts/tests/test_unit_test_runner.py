"""Exercise candidate resolution, native test ordering and authored-state recovery."""

import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('unit_runner', ROOT / 'scripts/run_unit_tests.py')
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)
DART = shutil.which('dart')
if DART:
    embedded = Path(DART).resolve().parent / 'cache/dart-sdk/bin/dart'
    if embedded.is_file():
        DART = str(embedded)


@unittest.skipUnless(DART, 'Dart is required for the actual override generator')
class UnitTestRunnerTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix='zstd-unit-runner-')
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name).resolve() / 'workspace with spaces'
        (self.root / 'scripts').mkdir(parents=True)
        shutil.copyfile(ROOT / 'scripts/create_local_overrides.dart', self.root / 'scripts/create_local_overrides.dart')
        for name in ['test_all.sh', 'run_unit_tests.py']:
            shutil.copyfile(ROOT / 'scripts' / name, self.root / 'scripts' / name)
        for package in RUNNER.PACKAGES + ['zstandard_native']:
            (self.root / package).mkdir()
            if package not in ['zstandard_cli', 'zstandard_platform_interface', 'zstandard_native']:
                (self.root / package / 'example').mkdir()
        (self.root / 'zstandard_android/example_legacy').mkdir()
        tools = self.root / 'tools'
        tools.mkdir()
        self.trace = self.root / 'trace.jsonl'
        tool = '''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
args=sys.argv[1:]
sdk=Path(sys.argv[0]).name
folder=Path.cwd()
package=folder.name
if sdk=='dart' and args and args[0].endswith('create_local_overrides.dart'):
    os.execv(os.environ['REAL_DART'], [os.environ['REAL_DART'], *args])
with open(os.environ['TRACE'], 'a') as trace:
    trace.write(json.dumps({'sdk':sdk,'args':args,'package':package,'ld':os.environ.get('LD_LIBRARY_PATH')})+'\\n')
if args[:2]==['pub','get']:
    assert '--no-example' in args
    if package!='zstandard_platform_interface':
        assert (folder/'pubspec_overrides.yaml').is_file()
elif args[:2]==['build','linux']:
    if os.environ.get('FAIL_BUILD')=='true': sys.exit(7)
    library=folder/'build/linux/x64/debug/bundle/lib/libzstandard_linux_plugin.so'
    library.parent.mkdir(parents=True,exist_ok=True)
    library.write_bytes(b'unit-fixture; actual plugin build is checked by Linux CI')
elif args and args[0]=='test':
    if sdk=='flutter': assert '--no-pub' in args
    if package=='zstandard_linux' and (sys.platform=='linux' or os.environ.get('EXPECT_LINUX_PLUGIN')=='true'):
        library=folder/'example/build/linux/x64/debug/bundle/lib/libzstandard_linux_plugin.so'
        assert library.is_file()
        assert str(library.parent) in os.environ.get('LD_LIBRARY_PATH','').split(os.pathsep)
    if os.environ.get('FAIL_PACKAGE')==package: sys.exit(8)
else:
    sys.exit(99)
'''
        for name in ['dart', 'flutter']:
            executable = tools / name
            executable.write_text(tool)
            executable.chmod(0o700)
        self.environment = {'PATH': str(tools) + os.pathsep + os.environ['PATH'],
                            'HOME': self.folder.name, 'REAL_DART': DART,
                            'TRACE': str(self.trace)}

    def run_suite(self, **settings):
        with patch.dict(os.environ, {**self.environment, 'EXPECT_LINUX_PLUGIN': 'true', **settings}, clear=True), \
             patch.object(RUNNER.platform, 'system', return_value='Linux'), \
             patch.object(RUNNER.platform, 'machine', return_value='x86_64'):
            return RUNNER.run_suite(self.root)

    def events(self):
        return [json.loads(line) for line in self.trace.read_text().splitlines()] if self.trace.exists() else []

    def test_runs_every_existing_suite_after_local_resolution_and_real_build_step(self):
        self.assertEqual(self.run_suite(), 0)
        events = self.events()
        self.assertEqual([event['package'] for event in events if event['args'][0] == 'test'], RUNNER.PACKAGES)
        build = next(i for i, event in enumerate(events) if event['args'][:2] == ['build', 'linux'])
        linux = next(i for i, event in enumerate(events) if event['package'] == 'zstandard_linux' and event['args'][0] == 'test')
        self.assertLess(build, linux)
        self.assertEqual(list(self.root.glob('**/pubspec_overrides.yaml')), [])

    def test_configured_shell_entry_point_runs_the_same_suites(self):
        result = subprocess.run(['bash', str(self.root / 'scripts/test_all.sh')],
                                cwd=self.folder.name, env=self.environment,
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([event['package'] for event in self.events() if event['args'][0] == 'test'], RUNNER.PACKAGES)

    def test_original_local_overrides_are_restored_after_a_failed_suite(self):
        original = self.root / 'zstandard/pubspec_overrides.yaml'
        content = b'dependency_overrides:\n  authored_package:\n    path: /authored path\n'
        original.write_bytes(content)
        original.chmod(0o640)
        self.assertEqual(self.run_suite(FAIL_PACKAGE='zstandard_android'), 1)
        self.assertEqual(original.read_bytes(), content)
        self.assertEqual(original.stat().st_mode & 0o777, 0o640)
        self.assertEqual([event['package'] for event in self.events() if event['args'][0] == 'test'], RUNNER.PACKAGES)
        self.assertEqual(list(self.root.glob('**/pubspec_overrides.yaml')), [original])

    def test_failed_native_build_cannot_run_linux_tests_but_keeps_other_suites(self):
        self.assertEqual(self.run_suite(FAIL_BUILD='true'), 1)
        packages = [event['package'] for event in self.events() if event['args'][0] == 'test']
        self.assertNotIn('zstandard_linux', packages)
        self.assertEqual(packages, [package for package in RUNNER.PACKAGES if package != 'zstandard_linux'])
        self.assertEqual(list(self.root.glob('**/pubspec_overrides.yaml')), [])

    def test_override_symlink_is_rejected_before_any_helper_or_test(self):
        outside = Path(self.folder.name) / 'authored-external.yaml'
        outside.write_text('authored sentinel\n')
        (self.root / 'zstandard/pubspec_overrides.yaml').symlink_to(outside)
        self.assertEqual(self.run_suite(), 1)
        self.assertEqual(outside.read_text(), 'authored sentinel\n')
        self.assertEqual(self.events(), [])


if __name__ == '__main__':
    unittest.main()
