"""Exercise the Web launcher across a shell that strips exported functions."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class WebIntegrationRunnerTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix='zstd-web-runner-')
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name).resolve() / 'workspace with spaces'
        (self.root / 'scripts').mkdir(parents=True)
        for directory in ['test', 'example/integration_test', 'example/test_driver']:
            (self.root / 'zstandard_web' / directory).mkdir(parents=True)
        shutil.copyfile(ROOT / 'scripts/test_web_integration.sh',
                        self.root / 'scripts/test_web_integration.sh')
        tools = self.root / 'tools'
        tools.mkdir()
        self.write_tool(tools / 'uname', '#!/bin/sh\necho Linux\n')
        self.write_tool(tools / 'curl', '#!/bin/sh\nexit 0\n')
        self.write_tool(tools / 'sleep', '#!/bin/sh\nexit 0\n')
        self.write_tool(tools / 'chromedriver', '#!/bin/sh\nexit 99\n')
        self.write_tool(tools / 'xvfb-run', '''#!/usr/bin/env python3
import os,sys
args=sys.argv[1:]
while args and args[0].startswith('--'):
    args.pop(0)
env={key:value for key,value in os.environ.items()
     if not key.startswith('BASH_FUNC_') and not value.startswith('() {')}
os.execvpe(args[0],args,env)
''')
        self.write_tool(tools / 'flutter', '''#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
Path(os.environ['TRACE']).write_text(json.dumps({'args':sys.argv[1:],'cwd':os.getcwd()}))
mode=os.environ['DRIVER_RESULT']
if mode=='missing-marker':
    print('Driver returned without executing tests.')
else:
    print('All tests passed!')
if mode=='compile-failure':
    print('Failed to compile application.')
sys.exit(7 if mode=='failed-process' else 0)
''')
        self.trace = self.root / 'trace.json'
        self.env = {**os.environ, 'PATH': str(tools) + os.pathsep + os.environ['PATH'],
                    'BASH_ENV': os.devnull, 'TRACE': str(self.trace),
                    'CHROME_EXECUTABLE': '/fixture browser/Chrome Browser',
                    'ZSTANDARD_WEB_PORT': '12345'}
        self.env.pop('ZSTANDARD_SKIP_WEB', None)

    @staticmethod
    def write_tool(path, content):
        path.write_text(content)
        path.chmod(0o700)

    def run_driver(self, result):
        return subprocess.run(['bash', str(self.root / 'scripts/test_web_integration.sh')],
                              cwd=self.root, env={**self.env, 'DRIVER_RESULT': result},
                              capture_output=True, text=True, timeout=20)

    def test_driver_survives_a_wrapper_that_strips_exported_functions(self):
        result = self.run_driver('success')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        trace = json.loads(self.trace.read_text())
        self.assertEqual(trace['cwd'], str(self.root / 'zstandard_web/example'))
        self.assertEqual(trace['args'][0], 'drive')
        self.assertIn('--chrome-binary=/fixture browser/Chrome Browser', trace['args'])
        self.assertIn('--driver-port=4444', trace['args'])
        self.assertIn('--web-port=12345', trace['args'])

    def test_driver_requires_process_success_and_positive_test_evidence(self):
        for mode in ['missing-marker', 'compile-failure', 'failed-process']:
            with self.subTest(mode=mode):
                self.trace.unlink(missing_ok=True)
                result = self.run_driver(mode)
                self.assertTrue(self.trace.exists(), result.stdout + result.stderr)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
