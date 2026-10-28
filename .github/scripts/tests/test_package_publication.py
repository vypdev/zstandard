"""Run publication shell steps with a clocked registry/SDK fixture, without uploads."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[3]
WORKFLOW = '.github/workflows/publish_workflow.yml'
COMPOSITE = '.github/actions/publish-package/action.yml'
ORDER = ['zstandard_platform_interface', 'zstandard_native', 'zstandard_android',
         'zstandard_ios', 'zstandard_linux', 'zstandard_macos', 'zstandard_web',
         'zstandard_windows', 'zstandard_cli', 'zstandard']


class PackagePublicationTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix='zstd-publisher-test-')
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name) / 'workspace with spaces'
        self.root.mkdir()
        for package in ORDER:
            (self.root / package).mkdir()
        self.state = self.root / 'registry.json'
        self.state.write_text(json.dumps({'clock': 0, 'issued': None, 'events': []}))
        tools = self.root / 'tools'
        tools.mkdir()
        source = '''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
path = Path(os.environ['REGISTRY_STATE'])
state = json.loads(path.read_text())
args = sys.argv[1:]
tool = Path(sys.argv[0]).name
package = Path.cwd().name
code = 0
if tool == 'setup-sdk':
    state['issued'] = state['clock']
    state['events'].append(['credential', state['clock']])
    # setup-dart inherits the composite's action path. Its optional matcher
    # command fails in the runner when that parent has no analyzer asset.
    if os.environ.get('INPUT_PROBLEM-MATCHER', 'true') != 'false':
        matcher = Path(os.environ['GITHUB_ACTION_PATH']) / 'dart-analyzer.json'
        state['events'].append(['matcher', str(matcher)])
        if not matcher.is_file():
            code = 66
elif args[:2] == ['pub', 'get']:
    state['events'].append(['resolve', package, tool])
    if os.environ.get('FAIL_RESOLVE') == package:
        code = 43
    elif tool == 'flutter' and package == 'zstandard_web' and '--no-example' not in args:
        # Flutter otherwise resolves the Web example's conflicting path/hosted sources.
        code = 42
elif args[:2] == ['run', 'scripts/publish_if_missing.dart']:
    package = args[2]
    if package in os.environ.get('ALREADY_PUBLISHED', '').split(','):
        state['events'].append(['skip', package])
    elif state['issued'] is None or state['clock'] - state['issued'] >= 300:
        code = 65
    else:
        state['events'].append(['publish', package])
elif args[:2] == ['run', 'scripts/wait_for_pub_version.dart']:
    state['events'].append(['indexed', args[2]])
    state['clock'] += 120
else:
    code = 99
path.write_text(json.dumps(state))
sys.exit(code)
'''
        for name in ['dart', 'flutter', 'setup-sdk']:
            executable = tools / name
            executable.write_text(source)
            executable.chmod(0o700)
        # setup-python's Linux interpreter needs its shared-library search path
        # even when fixture commands run with an otherwise isolated environment.
        self.env = {key: value for key, value in os.environ.items()
                    if key in ['PATH', 'LD_LIBRARY_PATH', 'SYSTEMROOT']}
        self.env.update(PATH=str(tools) + os.pathsep + self.env['PATH'],
                        HOME=self.folder.name, BASH_ENV=os.devnull,
                        REGISTRY_STATE=str(self.state))
        self.action_path = self.root / 'composite action with spaces'
        self.action_path.mkdir()
        self.env['GITHUB_ACTION_PATH'] = str(self.action_path)
        self.action = yaml.safe_load((ROOT / COMPOSITE).read_text())
        workflow = yaml.safe_load((ROOT / WORKFLOW).read_text())
        self.calls = [step for step in workflow['jobs']['publish']['steps']
                      if step.get('uses') == './.github/actions/publish-package']

    def run_package(self, package):
        inputs = {'package': package, 'version': '9.8.7', 'dart-version': '3.12.0'}
        for step in self.action['runs']['steps']:
            if 'uses' in step:
                self.assertEqual(step['uses'], 'dart-lang/setup-dart@v1')
                self.assertEqual(step['with']['sdk'], '${{ inputs.dart-version }}')
                sdk_env = {**self.env, 'INPUT_PROBLEM-MATCHER': str(
                    step.get('with', {}).get('problem-matcher', 'true')).lower()}
                result = subprocess.run(['setup-sdk'], env=sdk_env, capture_output=True,
                                        text=True, timeout=10)
                if result.returncode:
                    return result
                continue
            env = dict(self.env)
            for key, value in step.get('env', {}).items():
                for name, content in inputs.items():
                    value = value.replace('${{ inputs.' + name + ' }}', content)
                self.assertNotIn('${{', value)
                env[key] = value
            result = subprocess.run(['bash', '-e', '-o', 'pipefail', '-c', step['run']],
                                    cwd=self.root, env=env, capture_output=True,
                                    text=True, timeout=10)
            if result.returncode:
                return result
        return result

    def run_release(self):
        for call in self.calls:
            result = self.run_package(call['with']['package'])
            if result.returncode:
                return result
        return result

    def events(self, kind):
        return [event[1:] for event in json.loads(self.state.read_text())['events']
                if event[0] == kind]

    def test_all_packages_publish_in_order_across_expiring_credentials(self):
        self.assertEqual([call['with']['package'] for call in self.calls], ORDER)
        result = self.run_release()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.events('publish'), [[package] for package in ORDER])
        self.assertEqual(self.events('indexed'), [[package] for package in ORDER])
        self.assertEqual(self.events('credential'), [[120 * i] for i in range(10)])
        self.assertEqual([event[0] for event in self.events('resolve')], ORDER)

    def test_retry_skips_immutable_versions_and_continues_remaining_packages(self):
        self.env['ALREADY_PUBLISHED'] = ','.join(ORDER[:6])
        result = self.run_release()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.events('skip'), [[package] for package in ORDER[:6]])
        self.assertEqual(self.events('publish'), [[package] for package in ORDER[6:]])

    def test_nested_sdk_matcher_failure_stops_before_any_package_upload(self):
        self.action['runs']['steps'][0]['with'].pop('problem-matcher', None)
        result = self.run_release()
        self.assertEqual(result.returncode, 66)
        self.assertEqual(self.events('credential'), [[0]])
        self.assertEqual(self.events('matcher'), [
            [str(self.action_path / 'dart-analyzer.json')]])
        self.assertEqual(self.events('resolve'), [])
        self.assertEqual(self.events('publish'), [])

    def test_resolution_failure_stops_before_uploading_or_starting_next_package(self):
        self.env['FAIL_RESOLVE'] = 'zstandard_web'
        result = self.run_release()
        self.assertEqual(result.returncode, 43)
        self.assertEqual(self.events('publish'), [[package] for package in ORDER[:6]])
        self.assertEqual([event[0] for event in self.events('resolve')], ORDER[:7])

    def test_invalid_package_cannot_reach_dependency_resolution(self):
        result = self.run_package('../outside')
        self.assertEqual(result.returncode, 2)
        self.assertEqual(self.events('resolve'), [])
        self.assertEqual(self.events('publish'), [])


if __name__ == '__main__':
    unittest.main()
