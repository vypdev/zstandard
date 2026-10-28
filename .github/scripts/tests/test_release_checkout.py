"""Exercise release cache retirement with real Git repositories, without uploads."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[3]
ACTION = ROOT / '.github/actions/checkout-release-source'
USE = '$/.github/actions/checkout-release-source'
NODE = '''
try {
  const result = require(process.argv[1])({core: {notice() {}}});
  console.log(JSON.stringify(result));
} catch (error) { console.error(error.message); process.exitCode = 1; }
'''


class ReleaseCheckoutTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix='zstandard checkout tests ')
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name).resolve()
        self.environment = {k: v for k, v in os.environ.items() if not k.startswith('GIT_')}
        self.environment.update({'GIT_CONFIG_GLOBAL': os.devnull, 'GIT_CONFIG_NOSYSTEM': '1',
                                 'GIT_AUTHOR_NAME': 'Fixture', 'GIT_COMMITTER_NAME': 'Fixture',
                                 'GIT_AUTHOR_EMAIL': 'fixture@example.invalid',
                                 'GIT_COMMITTER_EMAIL': 'fixture@example.invalid'})
        self.source = self.root / 'source'
        self.source.mkdir()
        self.git(self.source, 'init', '-q', '-b', 'main')
        for text in ['first', 'second']:
            (self.source / 'file.txt').write_text(text)
            self.git(self.source, 'add', 'file.txt')
            self.git(self.source, 'commit', '-qm', text)
        self.case_number = 0

    def git(self, directory, *arguments):
        return subprocess.run(['git', '-C', str(directory), *arguments], check=True,
                              capture_output=True, text=True, env=self.environment).stdout.strip()

    def case(self, shallow=True):
        self.case_number += 1
        work = self.root / f'runner {self.case_number}' / 'work'
        temporary = work / '_temp'
        temporary.mkdir(parents=True)
        workspace = work / 'zstandard/zstandard'
        workspace.parent.mkdir()
        command = ['clone', '-q'] + (['--depth=1'] if shallow else [])
        self.git(self.root, *command, self.source.as_uri(), str(workspace))
        self.git(workspace, 'remote', 'set-url', 'origin', 'https://github.com/vypdev/zstandard')
        environment = {**self.environment, 'GITHUB_ACTIONS': 'true',
                       'GITHUB_REPOSITORY': 'vypdev/zstandard', 'GITHUB_RUN_ID': '123',
                       'GITHUB_RUN_ATTEMPT': '1', 'GITHUB_WORKSPACE': str(workspace),
                       'RUNNER_TEMP': str(temporary)}
        return workspace, temporary, environment

    def retire(self, environment):
        return subprocess.run(['node', '-e', NODE, str(ACTION / 'retire-shallow-cache.cjs')],
                              env=environment, capture_output=True, text=True, timeout=20)

    def test_shallow_cache_is_preserved_and_a_fresh_fetch_has_complete_history(self):
        workspace, temporary, environment = self.case()
        original_head = self.git(workspace, 'rev-parse', 'HEAD')
        self.assertEqual(self.git(workspace, 'rev-list', '--count', 'HEAD'), '1')
        result = self.retire(environment)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(json.loads(result.stdout)['retired'])
        self.assertFalse((workspace / '.git').exists())
        self.assertEqual((workspace / 'file.txt').read_text(), 'second')
        retired = next(temporary.glob('zstandard-shallow-git-*'))
        self.assertEqual((retired / 'git/HEAD').read_text().strip().split()[-1], 'refs/heads/main')
        self.assertEqual(json.loads((retired / '.owner').read_text())['head'], original_head)
        self.assertTrue((retired / 'git/shallow').is_file())
        # The next official checkout creates a new store, retaining full ancestry.
        self.git(workspace, 'init', '-q')
        self.git(workspace, 'remote', 'add', 'origin', self.source.as_uri())
        self.git(workspace, 'fetch', '-q', 'origin', '+refs/heads/*:refs/remotes/origin/*')
        self.git(workspace, 'checkout', '-qf', '-B', 'main', 'origin/main')
        self.assertEqual(self.git(workspace, 'rev-parse', '--is-shallow-repository'), 'false')
        self.assertEqual(self.git(workspace, 'rev-list', '--count', 'HEAD'), '2')
        self.git(workspace, 'fsck', '--connectivity-only', '--no-dangling')

    def test_complete_or_new_checkout_does_not_retire_metadata(self):
        workspace, temporary, environment = self.case(shallow=False)
        inode = (workspace / '.git').stat().st_ino
        result = self.retire(environment)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(json.loads(result.stdout)['retired'])
        self.assertEqual((workspace / '.git').stat().st_ino, inode)
        self.assertEqual(list(temporary.iterdir()), [])
        (workspace / '.git').rename(self.root / 'complete-fixture-metadata')
        result = self.retire(environment)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(json.loads(result.stdout)['retired'])

    def test_authored_changes_stashes_and_unpublished_branches_are_retained(self):
        for state in ['dirty', 'untracked', 'stash', 'unpublished']:
            with self.subTest(state=state):
                workspace, temporary, environment = self.case()
                if state == 'untracked':
                    (workspace / 'authored.txt').write_text('retain me')
                else:
                    (workspace / 'file.txt').write_text('retain me')
                    if state == 'stash':
                        self.git(workspace, 'stash', 'push', '-q')
                    if state == 'unpublished':
                        self.git(workspace, 'add', 'file.txt')
                        self.git(workspace, 'commit', '-qm', 'unpublished authored work')
                inode = (workspace / '.git').stat().st_ino
                head = self.git(workspace, 'rev-parse', 'HEAD')
                result = self.retire(environment)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual((workspace / '.git').stat().st_ino, inode)
                self.assertEqual(self.git(workspace, 'rev-parse', 'HEAD'), head)
                self.assertEqual(list(temporary.iterdir()), [])

    def test_unrelated_workspace_repository_links_and_locks_are_rejected(self):
        for state in ['outside', 'wrong-origin', 'linked', 'lock', 'worktree']:
            with self.subTest(state=state):
                workspace, temporary, environment = self.case()
                if state == 'outside':
                    environment['RUNNER_TEMP'] = str(self.root)
                elif state == 'wrong-origin':
                    self.git(workspace, 'remote', 'set-url', 'origin', 'https://github.com/other/repository')
                elif state == 'linked':
                    (workspace / '.git').rename(temporary / 'original-git')
                    (workspace / '.git').symlink_to(temporary / 'original-git', target_is_directory=True)
                elif state == 'lock':
                    (workspace / '.git/index.lock').touch()
                elif state == 'worktree':
                    (workspace / '.git/worktrees/active').mkdir(parents=True)
                result = self.retire(environment)
                self.assertNotEqual(result.returncode, 0)
                self.assertTrue((workspace / '.git').exists())
                self.assertEqual(list(temporary.glob('zstandard-shallow-git-*')), [])

    def test_release_jobs_keep_exact_refs_and_complete_history(self):
        action = yaml.safe_load((ACTION / 'action.yml').read_text())
        checkout = action['runs']['steps'][-1]
        self.assertEqual(checkout['uses'], 'actions/checkout@v6')
        self.assertEqual(action['inputs']['fetch-depth']['default'], '0')
        for name, count in [('release_workflow.yml', 11), ('publish_workflow.yml', 2)]:
            workflow = yaml.safe_load((ROOT / '.github/workflows' / name).read_text())
            calls = [step for job in workflow['jobs'].values() for step in job.get('steps', [])
                     if step.get('uses') == USE]
            self.assertEqual(len(calls), count)
            self.assertTrue(all(str(call['with']['fetch-depth']) == '0' for call in calls))
        workflow = yaml.safe_load((ROOT / '.github/workflows/publish_workflow.yml').read_text())
        self.assertEqual(workflow['jobs']['publish']['steps'][0]['with']['ref'],
                         '${{ needs.validate_tag.outputs.commit }}')

    def test_checkout_free_local_action_does_not_allow_remote_commit_pins(self):
        folder = self.root / 'policy/.github/workflows'
        folder.mkdir(parents=True)
        path = folder / 'fixture.yml'
        command = [sys.executable, str(ROOT / '.github/scripts/check_action_versions.py'), str(folder.parents[1])]
        path.write_text(f'jobs:\n  fixture:\n    steps:\n      - uses: {USE}\n      - uses: actions/checkout@v6\n')
        self.assertEqual(subprocess.run(command, capture_output=True).returncode, 0)
        path.write_text('jobs:\n  fixture:\n    steps:\n      - uses: actions/checkout@' + 'a' * 40 + '\n')
        self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)


if __name__ == '__main__':
    unittest.main()
