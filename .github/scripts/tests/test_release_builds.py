"""Execute release workflow commands without publishing or building binaries."""

import os
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[3]
WORKFLOW = yaml.load((ROOT / '.github/workflows/release_workflow.yml').read_text(), Loader=yaml.BaseLoader)


class ReleaseBuildTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix='zstd-release-build-')
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name).resolve() / 'workspace with spaces'
        self.root.mkdir()
        template = Path(self.folder.name) / 'template'
        template.mkdir()
        self.env = {**os.environ, 'GIT_CONFIG_GLOBAL': os.devnull,
                    'GIT_CONFIG_NOSYSTEM': '1', 'GIT_TEMPLATE_DIR': str(template),
                    'GITHUB_WORKSPACE': str(self.root), 'RELEASE_BRANCH': 'release/1.6.0',
                    'GITHUB_OUTPUT': str(self.root / 'outputs')}

    def git(self, *args):
        return subprocess.run(['git', *args], cwd=self.root, env=self.env, check=True,
                              capture_output=True, text=True).stdout.strip()

    def run_command(self, script):
        return subprocess.run(['bash', '-e', '-o', 'pipefail', '-c', script],
                              cwd=self.root, env=self.env, text=True,
                              capture_output=True, timeout=30)

    def commit_command(self, platform):
        return next(step['run'] for step in WORKFLOW['jobs'][f'cli_build_{platform}_precompiled_libs']['steps']
                    if step.get('id') == 'candidate')

    def initialize_origin(self):
        self.git('init', '-q', '-b', 'release/1.6.0')
        self.git('config', 'user.name', 'Fixture')
        self.git('config', 'user.email', 'fixture@example.invalid')
        binary = self.root / 'zstandard_cli/lib/src/bin/libzstandard_macos.dylib'
        binary.parent.mkdir(parents=True)
        binary.write_bytes(b'built library')
        self.git('add', 'zstandard_cli')
        self.git('commit', '-qm', 'candidate')
        origin = Path(self.folder.name) / 'origin.git'
        subprocess.run(['git', 'init', '--bare', '-q', str(origin)], env=self.env, check=True)
        self.git('remote', 'add', 'origin', str(origin))
        self.git('push', '-q', 'origin', 'HEAD:release/1.6.0')
        return binary

    def test_native_commit_steps_accept_unchanged_retries_and_record_the_sha(self):
        binary = self.initialize_origin()
        for platform in ['macos', 'linux']:
            with self.subTest(platform=platform):
                before = self.git('rev-parse', 'HEAD')
                for _ in range(2):
                    result = self.run_command(self.commit_command(platform))
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertEqual(self.git('rev-parse', 'HEAD'), before)
                binary.write_bytes(binary.read_bytes() + b' rebuilt')
                result = self.run_command(self.commit_command(platform))
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertNotEqual(self.git('rev-parse', 'HEAD'), before)
                self.assertEqual(self.git('rev-parse', 'HEAD'), self.git('rev-parse', 'refs/remotes/origin/release/1.6.0'))
        self.assertIn('commit=' + self.git('rev-parse', 'HEAD'), (self.root / 'outputs').read_text())

    def test_native_commit_step_does_not_overwrite_a_moved_remote(self):
        binary = self.initialize_origin()
        self.git('commit', '--allow-empty', '-qm', 'remote advanced')
        remote = self.git('rev-parse', 'HEAD')
        self.git('push', '-q', 'origin', 'HEAD:release/1.6.0')
        self.git('checkout', '--detach', '-q', 'HEAD~1')
        binary.write_bytes(b'new library')
        result = self.run_command(self.commit_command('linux'))
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.git('ls-remote', 'origin', 'refs/heads/release/1.6.0').split()[0], remote)

    @unittest.skipUnless(shutil.which('cmake'), 'CMake is needed for actual path resolution')
    def test_arm_toolchain_path_resolves_in_real_cmake_with_a_spaced_workspace(self):
        steps = WORKFLOW['jobs']['cli_build_linux_precompiled_libs']['steps']
        build = next(step['run'] for step in steps if step.get('name') == 'Build x86_64 and arm64 libraries')
        command = re.search(r'cmake -S zstandard_cli/builders/linux_arm[^\n]*\\\n(?:[^\n]*\\\n)*[^\n]*', build).group(0)
        source = self.root / 'zstandard_cli/builders/linux_arm'
        source.mkdir(parents=True)
        (source / 'CMakeLists.txt').write_text('cmake_minimum_required(VERSION 3.16)\nproject(path_contract NONE)\n')
        (source / 'arm64-toolchain.cmake').write_text('set(CMAKE_SYSTEM_NAME Linux)\n')
        result = self.run_command(command)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    @unittest.skipUnless(shutil.which('cmake'), 'CMake is needed for actual path resolution')
    def test_linux_native_tests_reconfigure_the_existing_flutter_build_directory(self):
        build = next(step['run'] for step in WORKFLOW['jobs']['candidate_linux']['steps']
                     if step.get('name') == 'Build, run native tests and run integration tests')
        command = build[build.index('cmake_build_dir='):build.index('cmake --build "$cmake_build_dir"')]
        example = self.root / 'zstandard_linux/example'
        source = example / 'linux'
        source.mkdir(parents=True)
        (source / 'CMakeLists.txt').write_text('cmake_minimum_required(VERSION 3.16)\nproject(path_contract NONE)\n')
        existing = example / 'build/linux/x64/release'
        existing.mkdir(parents=True)
        (existing / 'CMakeCache.txt').touch()
        result = self.run_command(command)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((existing / 'CMakeFiles').is_dir())

    def static_fixture(self):
        packages = ['zstandard_platform_interface', 'zstandard_native', 'zstandard_android',
                    'zstandard_ios', 'zstandard_linux', 'zstandard_macos', 'zstandard_web',
                    'zstandard_windows', 'zstandard_cli', 'zstandard']
        for package in packages:
            (self.root / package).mkdir(exist_ok=True)
        self.git('init', '-q')
        tools = self.root / 'tools'
        tools.mkdir()
        tool = '''#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
package=Path.cwd().name
args=sys.argv[1:]
if args[:2]==['pub','get']:
    with open(os.environ['TRACE'],'a') as trace:
        trace.write(json.dumps(['get',package])+'\\n')
    if package==os.environ.get('FAIL_RESOLVE'):
        sys.exit(23)
    Path('.resolved').touch()
elif args and args[0]=='format':
    with open(os.environ['TRACE'],'a') as trace:
        trace.write(json.dumps(['format',package])+'\\n')
    if not Path('.resolved').exists():
        sys.exit(31)
'''
        for name in ['dart', 'flutter']:
            (tools / name).write_text(tool)
            (tools / name).chmod(0o700)
        trace = self.root / 'trace'
        trace.touch()
        self.env.update(PATH=str(tools) + os.pathsep + self.env['PATH'],
                        VERSION='1.6.0', TRACE=str(trace))
        script = next(step['run'] for step in WORKFLOW['jobs']['candidate_static_checks']['steps']
                      if step.get('name') == 'Verify all release metadata and package tests')
        return packages, trace, script

    @unittest.skipUnless(shutil.which('cmake') and shutil.which('ctest'),
                         'CMake and CTest are needed for real test discovery')
    def test_native_ctest_requires_discovered_passing_tests(self):
        build = next(step['run'] for step in WORKFLOW['jobs']['candidate_linux']['steps']
                     if step.get('name') == 'Build, run native tests and run integration tests')
        command = next(line for line in build.splitlines() if line.startswith('ctest '))
        for outcome in ['passing', 'failing', 'empty']:
            with self.subTest(outcome=outcome):
                source = self.root / outcome
                plugin = source / 'plugins/zstandard_linux'
                plugin.mkdir(parents=True)
                # The empty case reproduces enable_testing() being called only
                # inside Flutter's plugin subdirectory rather than at the root.
                top_level = 'enable_testing()\n' if outcome != 'empty' else ''
                (source / 'CMakeLists.txt').write_text(
                    'cmake_minimum_required(VERSION 3.16)\nproject(ctest_contract NONE)\n'
                    + top_level + 'add_subdirectory(plugins/zstandard_linux)\n')
                (plugin / 'CMakeLists.txt').write_text(
                    'enable_testing()\nadd_test(NAME native_contract '
                    'COMMAND "${CMAKE_COMMAND}" -E '
                    + ('false' if outcome == 'failing' else 'true') + ')\n')
                directory = source / 'build'
                subprocess.run(['cmake', '-S', str(source), '-B', str(directory)],
                               env=self.env, check=True, capture_output=True, timeout=15)
                result = self.run_command(f'cmake_build_dir="{directory}"\n' + command)
                if outcome == 'passing':
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertIn('1/1 Test', result.stdout)
                else:
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_static_checks_resolve_each_package_before_formatting(self):
        packages, trace, script = self.static_fixture()
        result = self.run_command(script)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        calls = [json.loads(line) for line in trace.read_text().splitlines()]
        self.assertEqual(sorted(package for kind, package in calls if kind == 'format'),
                         sorted(packages))

    def test_static_checks_do_not_hide_dependency_resolution_failure(self):
        _, trace, script = self.static_fixture()
        self.env['FAIL_RESOLVE'] = 'zstandard_android'
        result = self.run_command(script)
        self.assertNotEqual(result.returncode, 0)
        calls = [json.loads(line) for line in trace.read_text().splitlines()]
        self.assertIn(['get', 'zstandard_android'], calls)
        self.assertNotIn(['format', 'zstandard_android'], calls)

    def test_linux_vm_tests_load_the_freshly_built_plugin(self):
        self.git('init', '-q')
        (self.root / 'zstandard_linux/example').mkdir(parents=True)
        tools = self.root / 'tools'
        tools.mkdir()
        flutter = tools / 'flutter'
        flutter.write_text('''#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
args=sys.argv[1:]
if args[:2]==['build','linux']:
    build=Path('build/linux/x64/release')
    (build/'bundle/lib').mkdir(parents=True)
    (build/'bundle/lib/libzstandard_linux_plugin.so').write_bytes(b'fixture plugin')
    (build/'CMakeCache.txt').touch()
    Path('main.dart').touch()
    Path('flutter-target').write_text(str(Path('main.dart').resolve()))
elif args and args[0]=='test':
    search=os.environ.get('LD_LIBRARY_PATH','').split(os.pathsep)
    with open(os.environ['TRACE'],'a') as trace:
        trace.write(json.dumps({'kind':'vm-test','search':search})+'\\n')
    if not any((Path(path)/'libzstandard_linux_plugin.so').is_file() for path in search):
        sys.exit(32)
''')
        flutter.chmod(0o700)
        (tools / 'cmake').write_text('''#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
if '--build' in sys.argv:
    target=Path(os.environ['NATIVE_TARGET']).read_text()
    if not Path(target).is_file():
        sys.exit(33)
    with open(os.environ['TRACE'],'a') as trace:
        trace.write(json.dumps({'kind':'native-build'})+'\\n')
''')
        (tools / 'cmake').chmod(0o700)
        (tools / 'ctest').write_text('#!/bin/sh\nexit 0\n')
        (tools / 'ctest').chmod(0o700)
        (self.root / 'scripts').mkdir()
        # Flutter's integration driver leaves generated_config.cmake pointing
        # at a test listener that it removes on exit. A subsequent native build
        # must not try to assemble that retired target.
        (self.root / 'scripts/test_linux_integration.sh').write_text(
            'printf "%s\\n" "$PWD/zstandard_linux/example/retired-listener.dart" '
            '> zstandard_linux/example/flutter-target\n')
        trace = self.root / 'trace'
        self.env.update(PATH=str(tools) + os.pathsep + self.env['PATH'], TRACE=str(trace),
                        NATIVE_TARGET=str(self.root / 'zstandard_linux/example/flutter-target'))
        script = next(step['run'] for step in WORKFLOW['jobs']['candidate_linux']['steps']
                      if step.get('name') == 'Build, run native tests and run integration tests')
        result = self.run_command(script)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        calls = [json.loads(line) for line in trace.read_text().splitlines()]
        vm_tests = [call for call in calls if call['kind'] == 'vm-test']
        self.assertEqual(len(vm_tests), 1)
        self.assertEqual(vm_tests[0]['search'][0],
                         str(self.root / 'zstandard_linux/example/build/linux/x64/release/bundle/lib'))
        self.assertEqual(sum(call['kind'] == 'native-build' for call in calls), 1)
        self.assertTrue(Path(self.env['NATIVE_TARGET']).read_text().endswith('/retired-listener.dart\n'))

    def test_release_admission_rejects_other_branches_before_checkout(self):
        script = WORKFLOW['jobs']['validate']['steps'][0]['with']['script']
        cases = [(prefix, ref, expected)
                 for prefix in ['release', 'deployment/release']
                 for ref, expected in [(f'refs/heads/{prefix}/1.6.0', 0), ('refs/heads/master', 1),
                                       ('refs/heads/develop', 1), ('refs/tags/v1.6.0', 1),
                                       (f'refs/heads/{prefix}/1.5.0', 1)]]
        cases.append(('deployment/release', 'refs/heads/release/1.6.0', 1))
        for prefix, ref, expected in cases:
            with self.subTest(prefix=prefix, ref=ref):
                env = {**self.env, 'MODE': 'prepare', 'OPERATION_ID': '', 'VERSION': '1.6.0',
                       'ISSUE': '7', 'TITLE': 'Fixture', 'CHANGELOG': 'Fixture',
                       'RELEASE_REF': ref, 'RELEASE_TREE': prefix}
                result = subprocess.run(['node', '-e', 'globalThis.core={setFailed:()=>{process.exitCode=1;}};\n' + script],
                                        env=env, text=True, capture_output=True, timeout=10)
                self.assertEqual(result.returncode, expected, result.stderr)

    def test_publication_recovery_retries_only_failed_matching_tag_pushes(self):
        steps = WORKFLOW['jobs']['publish']['steps']
        script = next(step['run'] for step in steps
                      if step.get('name') == 'Retry a failed publication of the same immutable tag')
        tools = self.root / 'tools'
        tools.mkdir()
        fake = tools / 'gh'
        fake.write_text('''#!/usr/bin/env python3
import json,os,sys
with open(os.environ['TRACE'], 'a') as trace:
    trace.write(json.dumps(sys.argv[1:])+'\\n')
if '/commits/' in sys.argv[2]:
    print('a'*40)
elif '/runs?' in sys.argv[2]:
    print(os.environ['RUNS'])
elif sys.argv[1:4] != ['api','--method','POST']:
    sys.exit(13)
''')
        fake.chmod(0o700)
        trace = self.root / 'trace'
        self.env.update(PATH=str(tools) + os.pathsep + self.env['PATH'], VERSION='1.6.0',
                        GITHUB_REPOSITORY='fixture/zstandard', TRACE=str(trace))
        for conclusion in ['failure', 'cancelled', 'timed_out', 'success', None]:
            for branch, event in [('v1.6.0', 'push'), ('v1.5.0', 'push'),
                                  ('v1.6.0', 'workflow_dispatch')]:
                with self.subTest(conclusion=conclusion, branch=branch, event=event):
                    trace.write_text('')
                    self.env['RUNS'] = json.dumps(dict(workflow_runs=[dict(
                        id=42, head_branch=branch, event=event,
                        status='completed' if conclusion else 'in_progress', conclusion=conclusion)]))
                    result = self.run_command(script)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    calls = [json.loads(line) for line in trace.read_text().splitlines()]
                    posts = [call for call in calls if '--method' in call]
                    expected = conclusion in ['failure', 'cancelled', 'timed_out'] and branch == 'v1.6.0' and event == 'push'
                    self.assertEqual(bool(posts), expected)
                    if posts:
                        self.assertEqual(posts, [['api', '--method', 'POST',
                                                 'repos/fixture/zstandard/actions/runs/42/rerun']])


if __name__ == '__main__':
    unittest.main()
