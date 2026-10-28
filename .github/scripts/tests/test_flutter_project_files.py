"""Run real save/restore steps against tracked Apple host fixtures without Flutter."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[3]
ACTION = './.github/actions/preserve-flutter-project-files'


class FlutterProjectFilesTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix='zstd-project-files-')
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name) / 'workspace with spaces'
        self.root.mkdir()
        self.temporary = Path(self.folder.name) / 'private state'
        self.temporary.mkdir()
        self.environment = {key: value for key, value in os.environ.items()
                            if not key.startswith('GIT_')}
        self.environment.update(RUNNER_TEMP=str(self.temporary), BASH_ENV=os.devnull,
                                GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1')
        self.git('init', '-q')
        action = yaml.safe_load((ROOT / ACTION.removeprefix('./') / 'action.yml').read_text())
        self.script = action['runs']['steps'][0]['run']

    def git(self, *args):
        subprocess.run(['git', *args], cwd=self.root, env=self.environment,
                       capture_output=True, check=True, timeout=10)

    def write(self, name, content):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def run_action(self, package, mode):
        result = subprocess.run(['bash', '-e', '-o', 'pipefail', '-c', self.script],
                                cwd=self.root, env={**self.environment, 'PACKAGE': package,
                                                   'MODE': mode}, capture_output=True,
                                text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_apple_migrations_restore_exact_starting_files_and_preserve_other_work(self):
        for platform in ['ios', 'macos']:
            with self.subTest(platform=platform):
                package = 'zstandard_' + platform
                project = f'{package}/example/{platform}/Runner.xcodeproj'
                paths = [f'{package}/analysis_options.yaml',
                         f'{package}/example/analysis_options.yaml',
                         project + '/project.pbxproj',
                         project + '/xcshareddata/xcschemes/Runner.xcscheme',
                         project + '/xcshareddata/settings with spaces.xml']
                for name in paths:
                    self.write(name, 'original ' + name)
                self.git('add', '--', package)
                # Preserve the actual starting worktree, including authored edits,
                # rather than replacing it with an assumed HEAD/index baseline.
                self.write(paths[2], 'authored baseline before Flutter ran')
                originals = {name: (self.root / name).read_bytes() for name in paths}
                self.run_action(package, 'save')
                for name in paths:
                    self.write(name, 'Flutter migration changed ' + name)
                scheme = self.root / paths[3]
                scheme.unlink()
                scheme.parent.rmdir()
                untracked = self.write(project + '/untracked-note.txt', 'retain untracked work')
                unrelated = self.write(package + '/lib/authored.dart', 'retain unrelated work')
                self.run_action(package, 'restore')
                for name, content in originals.items():
                    self.assertEqual((self.root / name).read_bytes(), content)
                self.assertEqual(untracked.read_text(), 'retain untracked work')
                self.assertEqual(unrelated.read_text(), 'retain unrelated work')

    def test_restore_without_a_snapshot_leaves_source_untouched(self):
        path = self.write('zstandard_ios/analysis_options.yaml', 'keep me')
        self.git('add', '--', 'zstandard_ios')
        self.run_action('zstandard_ios', 'restore')
        self.assertEqual(path.read_text(), 'keep me')
        self.assertFalse((self.temporary / 'flutter-project-files').exists())

    def test_non_apple_packages_keep_the_existing_analysis_only_scope(self):
        analysis = self.write('zstandard_web/analysis_options.yaml', 'original analysis')
        source = self.write('zstandard_web/lib/source.dart', 'original source')
        self.git('add', '--', 'zstandard_web')
        self.run_action('zstandard_web', 'save')
        analysis.write_text('Flutter analysis rewrite')
        source.write_text('authored source')
        self.run_action('zstandard_web', 'restore')
        self.assertEqual(analysis.read_text(), 'original analysis')
        self.assertEqual(source.read_text(), 'authored source')

    def test_apple_jobs_restore_after_integration_even_when_a_step_fails(self):
        for workflow, job, integration in [
            ('pr_check_ios.yml', 'check_ios_test', 'Run integration tests'),
            ('pr_check_macos.yml', 'check_macos_test',
             'Launch macOS example and run integration tests'),
            ('release_workflow.yml', 'candidate_apple', 'Run Apple integration tests'),
        ]:
            with self.subTest(workflow=workflow):
                data = yaml.safe_load((ROOT / '.github/workflows' / workflow).read_text())
                steps = data['jobs'][job]['steps']
                integration_index = next(i for i, step in enumerate(steps)
                                         if step.get('name') == integration)
                restore_index = max(i for i, step in enumerate(steps)
                                    if step.get('uses') == ACTION
                                    and step['with']['mode'] == 'restore')
                self.assertGreater(restore_index, integration_index)
                self.assertEqual(steps[restore_index]['if'], 'always()')


if __name__ == '__main__':
    unittest.main()
