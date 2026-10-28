"""Verify native tool settings survive only through reviewed PATH launchers."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[3]


class VerificationRuntimeTests(unittest.TestCase):
    def test_private_launchers_keep_native_paths_and_arguments_without_capturing_secrets(self):
        with tempfile.TemporaryDirectory(prefix='zstd-verification-env-') as temporary:
            root = Path(temporary).resolve()
            profile = root / 'profile with spaces'
            profile.mkdir()
            sdk = root / 'sdk with spaces'
            sdk.mkdir()
            trace = root / 'trace.json'
            for tool in ['flutter', 'dart']:
                executable = sdk / tool
                executable.write_text('''#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
keys=['CPATH','LD_LIBRARY_PATH','PKG_CONFIG_SYSROOT_DIR','PUB_CACHE','XDG_CONFIG_HOME','UNRELATED_SECRET']
Path(os.environ['TRACE']).write_text(json.dumps({'args':sys.argv[1:],'env':{key:os.environ.get(key) for key in keys}}))
''')
                executable.chmod(0o700)
            paths = root / 'github-path'
            paths.touch()
            header_path = str(root / 'headers $(touch unexpected)')
            environment = {'PATH': str(sdk) + os.pathsep + os.environ['PATH'],
                           'HOME': str(profile), 'GITHUB_PATH': str(paths),
                           'CPATH': header_path, 'LD_LIBRARY_PATH': str(root / 'private libraries'),
                           'PKG_CONFIG_SYSROOT_DIR': str(root / 'sysroot with spaces'),
                           'PUB_CACHE': str(profile / 'private cache'),
                           'XDG_CONFIG_HOME': str(profile / '.config'),
                           'UNRELATED_SECRET': 'must-not-be-captured'}
            subprocess.run(['bash', str(ROOT / '.github/actions/copilot-verification-setup/runtime-launchers.sh')],
                           env=environment, check=True, timeout=10)
            launcher = Path(paths.read_text().strip())
            self.assertTrue(launcher.is_relative_to(profile))
            for tool in ['flutter', 'dart']:
                probe = {'PATH': os.environ['PATH'], 'HOME': str(profile),
                         'TRACE': str(trace), 'LD_LIBRARY_PATH': str(root / 'actual test plugin')}
                subprocess.run([str(launcher / tool), 'literal $(touch unexpected)', 'two words'],
                               cwd=root, env=probe, check=True, timeout=10)
                result = json.loads(trace.read_text())
                self.assertEqual(result['args'], ['literal $(touch unexpected)', 'two words'])
                self.assertEqual(result['env']['CPATH'], header_path)
                self.assertEqual(result['env']['PKG_CONFIG_SYSROOT_DIR'], environment['PKG_CONFIG_SYSROOT_DIR'])
                self.assertEqual(result['env']['PUB_CACHE'], environment['PUB_CACHE'])
                self.assertEqual(result['env']['XDG_CONFIG_HOME'], environment['XDG_CONFIG_HOME'])
                self.assertEqual(result['env']['LD_LIBRARY_PATH'].split(os.pathsep),
                                 [environment['LD_LIBRARY_PATH'], probe['LD_LIBRARY_PATH']])
                self.assertIsNone(result['env']['UNRELATED_SECRET'])
                self.assertFalse((root / 'unexpected').exists())


if __name__ == '__main__':
    unittest.main()
