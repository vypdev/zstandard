"""Exercise real process locks and cancellation without using a host Android SDK."""

import contextlib
import fcntl
import importlib.util
import io
import json
import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import tempfile
import time
import unittest

sys.dont_write_bytecode = True
MODULE_PATH = Path(__file__).resolve().parents[1] / 'android_ci_session.py'
SPEC = importlib.util.spec_from_file_location('android_ci_session', MODULE_PATH)
SESSION = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SESSION)
ENTRY = '''
import importlib.util,json,sys
from pathlib import Path
sys.dont_write_bytecode=True
spec=importlib.util.spec_from_file_location('session',sys.argv[1])
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
raise SystemExit(module.run_session(json.loads(sys.argv[4]),Path(sys.argv[2]),float(sys.argv[3])))
'''


class AndroidSessionTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix='zstd-android-lock-')
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name)
        self.lock = self.root / 'shared host lease'

    def stop(self, process):
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=3)
        process.stdout.close()
        process.stderr.close()

    def start(self, command, timeout=5):
        process = subprocess.Popen([sys.executable, '-c', ENTRY, str(MODULE_PATH),
                                    str(self.lock), str(timeout), json.dumps(command)],
                                   env={**os.environ, 'PYTHONDONTWRITEBYTECODE': '1'},
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.addCleanup(self.stop, process)
        return process

    def wait_for(self, path):
        deadline = time.monotonic() + 5
        while not path.exists():
            if time.monotonic() >= deadline:
                self.fail('The fixture command did not reach its expected barrier.')
            time.sleep(0.01)

    def run_now(self, command, timeout=1):
        with contextlib.redirect_stdout(io.StringIO()):
            return SESSION.run_session(command, self.lock, timeout)

    def test_concurrent_runner_requests_serialize_the_complete_command(self):
        first_entered = self.root / 'first entered'
        release = self.root / 'release first'
        second_entered = self.root / 'second entered'
        first = self.start([sys.executable, '-c',
                            'from pathlib import Path;import sys,time;'
                            'Path(sys.argv[1]).touch();'
                            'exec("while not Path(sys.argv[2]).exists(): time.sleep(0.01)")',
                            str(first_entered), str(release)])
        self.wait_for(first_entered)
        second = self.start([sys.executable, '-c',
                             'from pathlib import Path;import sys;Path(sys.argv[1]).touch()',
                             str(second_entered)])
        self.assertTrue(select.select([second.stdout], [], [], 5)[0])
        self.assertEqual(second.stdout.readline().strip(),
                         'Waiting for the shared Android CI session.')
        self.assertFalse(second_entered.exists())
        release.touch()
        first.communicate(timeout=5)
        second.communicate(timeout=5)
        self.assertEqual(first.returncode, 0)
        self.assertEqual(second.returncode, 0)
        self.assertTrue(second_entered.exists())

    def test_command_failure_and_spawn_error_release_the_lease(self):
        self.assertEqual(self.run_now([sys.executable, '-c', 'raise SystemExit(43)']), 43)
        with self.assertRaises(FileNotFoundError):
            self.run_now([str(self.root / 'missing executable')])
        self.assertEqual(self.run_now([sys.executable, '-c', 'pass']), 0)

    def test_lock_timeout_never_runs_the_waiting_command(self):
        entered = self.root / 'must not enter'
        with self.lock.open('w') as held:
            fcntl.flock(held, fcntl.LOCK_EX)
            request = self.start([sys.executable, '-c',
                                  'from pathlib import Path;import sys;Path(sys.argv[1]).touch()',
                                  str(entered)], timeout=0.2)
            _, error = request.communicate(timeout=5)
            self.assertEqual(request.returncode, 75, error)
        self.assertFalse(entered.exists())

    def test_cancellation_reaches_the_worker_and_releases_the_lease(self):
        entered = self.root / 'worker entered'
        request = self.start([sys.executable, '-c',
                              'from pathlib import Path;import sys,time;'
                              'Path(sys.argv[1]).touch();time.sleep(60)', str(entered)])
        self.wait_for(entered)
        request.terminate()
        request.communicate(timeout=5)
        self.assertEqual(request.returncode, 128 + signal.SIGTERM)
        self.assertEqual(self.run_now([sys.executable, '-c', 'pass']), 0)

    def test_sdk_daemons_cannot_retain_the_parent_lease(self):
        pid_file = self.root / 'daemon pid'
        daemon = ('import subprocess,sys;from pathlib import Path;'
                  'p=subprocess.Popen([sys.executable,"-c","import time;time.sleep(60)"],'
                  'start_new_session=True,close_fds=False,stdout=subprocess.DEVNULL,'
                  'stderr=subprocess.DEVNULL);Path(sys.argv[1]).write_text(str(p.pid))')
        request = self.start([sys.executable, '-c', daemon, str(pid_file)])
        request.communicate(timeout=5)
        self.assertEqual(request.returncode, 0)
        pid = int(pid_file.read_text())
        try:
            self.assertEqual(self.run_now([sys.executable, '-c', 'pass'], timeout=0.3), 0)
        finally:
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass

    def test_symlink_lease_cannot_modify_an_unrelated_file(self):
        original = self.root / 'authored source'
        original.write_text('retain me')
        self.lock.symlink_to(original)
        with self.assertRaises(OSError):
            self.run_now([sys.executable, '-c', 'raise SystemExit(99)'])
        self.assertEqual(original.read_text(), 'retain me')


if __name__ == '__main__':
    unittest.main()
