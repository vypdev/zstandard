"""Exercise SDK provisioning from a tools-only runner without starting a device."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'run_android_emulator_ci.sh'


class AndroidProvisioningTests(unittest.TestCase):
    def exercise(self, install_fails, scenario='avd-fails'):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            sdk = root / 'sdk'
            tools = sdk / 'cmdline-tools/latest/bin'
            tools.mkdir(parents=True)
            timeout_fixture = tools / 'timeout'
            timeout_fixture.write_text('#!/bin/bash\nshift\nexec "$@"\n')
            timeout_fixture.chmod(0o755)
            trace = root / 'trace'
            manager = tools / 'sdkmanager'
            manager.write_text('''#!/bin/bash
set -eu
if [[ "$1" == --licenses ]]; then exit 0; fi
printf 'install\\n' >> "$TRACE"
if [[ "$INSTALL_FAILS" == true ]]; then exit 42; fi
mkdir -p "$ANDROID_SDK_ROOT/platform-tools" "$ANDROID_SDK_ROOT/emulator"
cp "$ADB_FIXTURE" "$ANDROID_SDK_ROOT/platform-tools/adb"
cp "$EMULATOR_FIXTURE" "$ANDROID_SDK_ROOT/emulator/emulator"
chmod +x "$ANDROID_SDK_ROOT/platform-tools/adb" "$ANDROID_SDK_ROOT/emulator/emulator"
''')
            avd = tools / 'avdmanager'
            avd.write_text('''#!/bin/bash
printf 'avd\\n' >> "$TRACE"
if [[ "$SCENARIO" == avd-fails ]]; then exit 43; fi
while [[ $# -gt 0 ]]; do
  if [[ "$1" == --name ]]; then shift; name="$1"; fi
  shift
done
mkdir -p "$ANDROID_AVD_HOME/$name.avd"
printf 'fixture\\n' > "$ANDROID_AVD_HOME/$name.avd/config.ini"
''')
            adb_fixture = root / 'adb fixture'
            adb_fixture.write_text('''#!/bin/bash
printf 'adb:%s\\n' "$*" >> "$TRACE"
if [[ "$1" == devices ]]; then
  printf 'List of devices attached\\n'
  if [[ "$SCENARIO" == occupied ]]; then printf 'emulator-5554\\toffline\\n'; fi
elif [[ "$*" == *'shell getprop'* ]]; then
  while [[ ! -e "$EMULATOR_STARTED" ]]; do sleep 0.01; done
  printf '1\\n'
elif [[ "$*" == *'emu avd name'* ]]; then
  printf 'foreign_avd\\nOK\\n'
fi
''')
            emulator_fixture = root / 'emulator fixture'
            emulator_fixture.write_text('''#!/bin/bash
printf 'emulator\\n' >> "$TRACE"
touch "$EMULATOR_STARTED"
trap 'exit 0' TERM
while true; do sleep 0.1; done
''')
            manager.chmod(0o755)
            avd.chmod(0o755)
            env = os.environ.copy()
            env.pop('ANDROID_USER_HOME', None)
            env.pop('ANDROID_AVD_HOME', None)
            env.update(HOME=str(root), ANDROID_HOME=str(sdk), ANDROID_SDK_ROOT=str(sdk),
                       RUNNER_TEMP=str(root / 'runner temp'),
                       PATH=str(tools) + ':/usr/bin:/bin', TRACE=str(trace),
                       SCENARIO=scenario, ADB_FIXTURE=str(adb_fixture),
                       EMULATOR_FIXTURE=str(emulator_fixture),
                       EMULATOR_STARTED=str(root / 'emulator started'),
                       PYTHONDONTWRITEBYTECODE='1',
                       INSTALL_FAILS=str(install_fails).lower())
            # Compose the real coordinator/worker with a private fixture lock;
            # tests must never wait on or provision the real host session.
            entry = '''
import importlib.util,sys
from pathlib import Path
sys.dont_write_bytecode=True
spec=importlib.util.spec_from_file_location('session',sys.argv[1])
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
raise SystemExit(module.run_session(['bash',sys.argv[3],'true'],Path(sys.argv[2]),1))
'''
            result = subprocess.run([sys.executable, '-c', entry,
                                     str(SCRIPT.parent / 'android_ci_session.py'),
                                     str(root / 'private lease'), str(SCRIPT)], env=env,
                                    text=True, capture_output=True, timeout=10)
            return result, trace.read_text() if trace.exists() else ''

    def test_tools_only_sdk_is_provisioned_before_emulator_validation(self):
        result, trace = self.exercise(False)
        self.assertEqual(result.returncode, 43, result.stdout + result.stderr)
        self.assertEqual(trace, 'install\navd\n')
        self.assertNotIn('executable is missing', result.stderr)

    def test_install_failure_stops_before_avd_or_device_creation(self):
        result, trace = self.exercise(True)
        self.assertEqual(result.returncode, 42, result.stdout + result.stderr)
        self.assertEqual(trace, 'install\n')

    def test_an_existing_offline_device_is_never_replaced(self):
        result, trace = self.exercise(False, scenario='occupied')
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('already in use', result.stderr)
        self.assertNotIn('\nemulator\n', trace)
        self.assertNotIn('emu kill', trace)

    def test_a_foreign_booted_avd_cannot_supply_false_readiness(self):
        result, trace = self.exercise(False, scenario='foreign')
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('different AVD', result.stderr)
        self.assertIn('\nemulator\n', trace)
        self.assertNotIn('emu kill', trace)
        self.assertNotIn('dumpsys', trace)


if __name__ == '__main__':
    unittest.main()
