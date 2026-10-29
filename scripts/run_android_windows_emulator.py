"""Run the candidate Android ELF smoke test in an isolated Windows AVD."""

import argparse
from contextlib import contextmanager
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time


@contextmanager
def emulator_lease():
    import msvcrt
    path = Path(tempfile.gettempdir()) / 'zstandard-windows-android-emulator.lock'
    with path.open('a+b') as lease:
        if path.stat().st_size == 0:
            lease.write(b'0')
            lease.flush()
        deadline = time.monotonic() + 600
        while True:
            lease.seek(0)
            try:
                msvcrt.locking(lease.fileno(), msvcrt.LK_NBLCK, 1)
                break
            except OSError:
                if time.monotonic() > deadline:
                    raise TimeoutError('Timed out waiting for this host\'s Android test lease.')
                print('Waiting for the Windows Android emulator lease.', flush=True)
                time.sleep(15)
        try:
            yield
        finally:
            lease.seek(0)
            msvcrt.locking(lease.fileno(), msvcrt.LK_UNLCK, 1)


def available_port_pair():
    for port in range(5600, 5680, 2):
        try:
            with socket.socket() as console, socket.socket() as adb:
                console.bind(('127.0.0.1', port))
                adb.bind(('127.0.0.1', port + 1))
            return port
        except OSError:
            continue
    raise RuntimeError('No unused emulator port pair is available.')


def execute(sdk, report):
    if os.name != 'nt':
        raise RuntimeError('This launcher is for the Windows self-hosted runner.')
    with emulator_lease(), tempfile.TemporaryDirectory(prefix='zstandard-avd-', dir=os.environ['RUNNER_TEMP']) as temporary:
        state = Path(temporary)
        avd_home = state / 'avd'
        avd_home.mkdir()
        name = 'zstandard-' + state.name
        environment = {**os.environ, 'ANDROID_HOME': str(sdk), 'ANDROID_SDK_ROOT': str(sdk),
                       'ANDROID_AVD_HOME': str(avd_home), 'ANDROID_USER_HOME': str(state / 'user')}
        Path(environment['ANDROID_USER_HOME']).mkdir()
        with socket.socket() as reservation:
            reservation.bind(('127.0.0.1', 0))
            adb_port = reservation.getsockname()[1]
        environment['ANDROID_ADB_SERVER_PORT'] = str(adb_port)
        environment['ADB_SERVER_SOCKET'] = f'tcp:127.0.0.1:{adb_port}'
        port = available_port_pair()
        device = f'emulator-{port}'
        receipt = {'software_emulation': True, 'avd': name, 'device': device,
                   'private_adb_port': adb_port, 'stage': 'create-avd', 'passed': False}
        (report / 'headless-execution.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')

        def command(arguments, filename, *, timeout=30, check=True, stdin=None):
            result = subprocess.run([str(arg) for arg in arguments], env=environment,
                                    input=stdin, capture_output=True, text=True,
                                    encoding='utf-8', errors='replace', timeout=timeout)
            output = result.stdout + result.stderr
            (report / filename).write_text(output, encoding='utf-8')
            if check and result.returncode:
                raise RuntimeError(f'{filename}: exit {result.returncode}: {output[-1800:]}')
            return result.returncode, output.strip()

        tools = sdk / 'cmdline-tools/latest'
        java = Path(os.environ['JAVA_HOME']) / 'bin/java.exe'
        command([java, '-Dfile.encoding=UTF-8', f'-Dcom.android.sdklib.toolsdir={tools}',
                 '-classpath', tools / 'lib/avdmanager-classpath.jar',
                 'com.android.sdklib.tool.AvdManagerCli', 'create', 'avd', '--name', name,
                 '--package', 'system-images;android-30;aosp_atd;x86_64', '--device', 'pixel_2'],
                'avd-create.txt', timeout=120, stdin='no\n')
        configuration = avd_home / f'{name}.avd/config.ini'
        if not configuration.is_file():
            raise RuntimeError('AVD manager did not create the private AVD configuration.')
        with configuration.open('a', encoding='utf-8') as stream:
            stream.write('\nhw.cpu.ncore=2\nhw.gps=no\n')
        adb = sdk / 'platform-tools/adb.exe'
        emulator = sdk / 'emulator/emulator.exe'
        process = None
        owned_device = False
        try:
            command([adb, '-P', adb_port, 'start-server'], 'adb-start.txt')
            receipt['stage'] = 'boot'
            with (report / 'emulator.txt').open('w', encoding='utf-8') as log:
                process = subprocess.Popen([str(emulator), '-avd', name, '-port', str(port),
                                            '-no-window', '-gpu', 'swiftshader_indirect',
                                            '-feature', '-Vulkan', '-feature', '-GnssGrpcV1',
                                            '-no-snapshot', '-no-snapshot-save', '-noaudio',
                                            '-no-boot-anim', '-camera-back', 'none', '-accel', 'off'],
                                           env=environment, stdout=log, stderr=subprocess.STDOUT)
                started = time.monotonic()
                while time.monotonic() - started < 900:
                    if process.poll() is not None:
                        raise RuntimeError('The software Android emulator exited before boot completed.')
                    _, boot = command([adb, '-P', adb_port, '-s', device, 'shell', 'getprop', 'sys.boot_completed'],
                                      'boot-state.txt', check=False)
                    if boot == '1':
                        _, registered = command([adb, '-P', adb_port, '-s', device, 'emu', 'avd', 'name'], 'avd-name.txt')
                        if registered.splitlines()[0] != name:
                            raise RuntimeError('Emulator port is owned by a different AVD; refusing to use it.')
                        owned_device = True
                        break
                    print(f'Waiting for software Android boot: {time.monotonic() - started:.0f}s.', flush=True)
                    time.sleep(10)
                if not owned_device:
                    raise TimeoutError('The software Android emulator did not boot within 15 minutes.')
                receipt['boot_seconds'] = time.monotonic() - started
                receipt['stage'] = 'native-execution'
                remote = '/data/local/tmp/' + name
                command([adb, '-P', adb_port, '-s', device, 'shell', 'mkdir', remote], 'device-mkdir.txt')
                try:
                    for filename in ['zstandard_android_smoke', 'libzstandard_android.so']:
                        command([adb, '-P', adb_port, '-s', device, 'push', report / 'runtime' / filename,
                                 remote + '/' + filename], 'device-push-' + filename + '.txt')
                    command([adb, '-P', adb_port, '-s', device, 'shell', 'chmod', '700', remote + '/zstandard_android_smoke'],
                            'device-chmod.txt')
                    _, output = command([adb, '-P', adb_port, '-s', device, 'shell',
                                         f'LD_LIBRARY_PATH={remote} {remote}/zstandard_android_smoke'],
                                        'native-runtime.txt', timeout=300)
                    if not output.startswith('PASS: Android shared library'):
                        raise RuntimeError('Native Android smoke test did not report success.')
                    print(output, flush=True)
                    receipt.update({'stage': 'complete', 'passed': True})
                finally:
                    command([adb, '-P', adb_port, '-s', device, 'shell', 'rm', '-rf', remote],
                            'device-cleanup.txt', check=False)
        except BaseException as error:
            receipt['error'] = str(error)
            if (report / 'emulator.txt').is_file():
                print((report / 'emulator.txt').read_text(encoding='utf-8', errors='replace')[-12000:], flush=True)
            raise
        finally:
            cleanup_errors = []

            def cleanup(arguments, filename):
                try:
                    command(arguments, filename, check=False)
                except Exception as error:
                    cleanup_errors.append(str(error))

            if owned_device:
                cleanup([adb, '-P', adb_port, '-s', device, 'emu', 'kill'], 'emulator-stop.txt')
            if process is not None:
                try:
                    process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    cleanup(['taskkill', '/PID', process.pid, '/T', '/F'], 'owned-process-stop.txt')
            # Only this job's private daemon, never the host's default ADB server.
            cleanup([adb, '-P', adb_port, 'kill-server'], 'adb-stop.txt')
            receipt['cleanup_errors'] = cleanup_errors
            (report / 'headless-execution.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
            if cleanup_errors and receipt['passed']:
                raise RuntimeError('Windows Android cleanup failed: ' + '; '.join(cleanup_errors))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sdk-root', type=Path, required=True)
    parser.add_argument('--report-directory', type=Path, required=True)
    arguments = parser.parse_args()
    execute(arguments.sdk_root.resolve(), arguments.report_directory.resolve())
