"""Download the reviewed Android tools into a fresh job-private Windows SDK."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import urllib.request
import zipfile

URL = 'https://dl.google.com/android/repository/commandlinetools-win-15859902_latest.zip'
SHA256 = '90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a'


def prepare(sdk, report):
    temporary = Path(os.environ.get('RUNNER_TEMP', tempfile.gettempdir())).resolve()
    sdk = sdk.resolve()
    if sdk.parent != temporary or sdk.exists():
        raise ValueError('Expected a fresh SDK directory directly inside RUNNER_TEMP.')
    sdk.mkdir()
    report.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    receipt = {'url': URL, 'expected_sha256': SHA256, 'sdk': str(sdk), 'stage': 'download'}

    def note(message):
        print(message, flush=True)
        with (report / 'android-tools-progress.txt').open('a', encoding='utf-8') as stream:
            stream.write(message + '\n')
        (report / 'android-tools-bootstrap.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')

    try:
        archive = sdk / 'command-line-tools.zip'
        digest = hashlib.sha256()
        downloaded = 0
        note('Downloading reviewed Android command-line tools with a five-minute total limit.')
        with urllib.request.urlopen(URL, timeout=30) as response, archive.open('wb') as output:
            while block := response.read(1024 * 1024):
                if time.monotonic() - started > 300:
                    raise TimeoutError('Android tools download exceeded five minutes.')
                digest.update(block)
                output.write(block)
                downloaded += len(block)
                if downloaded % (8 * 1024 * 1024) == 0:
                    receipt['downloaded_bytes'] = downloaded
                    note(f'Downloaded {downloaded // (1024 * 1024)} MiB in {time.monotonic() - started:.1f}s.')
        receipt.update({'downloaded_bytes': downloaded, 'sha256': digest.hexdigest()})
        if digest.hexdigest() != SHA256:
            raise ValueError('Android tools checksum mismatch.')
        receipt['stage'] = 'extract'
        note(f'Checksum verified after {time.monotonic() - started:.1f}s; extracting.')
        extracted = sdk / 'archive-root'
        with zipfile.ZipFile(archive) as package:
            for index, member in enumerate(package.infolist(), 1):
                destination = (extracted / member.filename).resolve()
                if not destination.is_relative_to(extracted.resolve()):
                    raise ValueError('Unsafe Android tools archive member.')
                package.extract(member, extracted)
                if index % 32 == 0:
                    note(f'Extracted {index} files in {time.monotonic() - started:.1f}s.')
        tools = sdk / 'cmdline-tools/latest'
        tools.parent.mkdir()
        shutil.move(str(extracted / 'cmdline-tools'), str(tools))
        if not (tools / 'bin/sdkmanager.bat').is_file():
            raise ValueError('The reviewed archive did not contain sdkmanager.bat.')
        extracted.rmdir()
        archive.unlink()
        receipt.update({'stage': 'ready', 'duration_seconds': time.monotonic() - started})
        note('Reviewed Android command-line tools are ready.')
    except Exception as error:
        receipt.update({'stage': 'failed', 'error': str(error), 'duration_seconds': time.monotonic() - started})
        note('Android command-line tools preparation failed: ' + str(error))
        raise


def install_packages(sdk, report):
    sdk = sdk.resolve()
    if sdk.parent != Path(os.environ['RUNNER_TEMP']).resolve():
        raise ValueError('Package installation must remain inside the job-private SDK.')
    tools = sdk / 'cmdline-tools/latest'
    java = Path(os.environ['JAVA_HOME']) / 'bin/java.exe'
    classpath = tools / 'lib/sdkmanager-classpath.jar'
    if not java.is_file() or not classpath.is_file():
        raise ValueError('The selected JDK and reviewed SDK manager are required.')
    # This is the Java invocation in the reviewed vendor sdkmanager.bat. Calling
    # it directly gives Java explicit UTF-8 stdin without a PowerShell/batch pipe.
    command = [str(java), '-Dfile.encoding=UTF-8',
               f'-Dcom.android.sdkmanager.toolsdir={tools}', '-classpath', str(classpath),
               'com.android.sdklib.tool.sdkmanager.SdkManagerCli', f'--sdk_root={sdk}']
    requested = ['ndk;27.0.12077973', 'cmake;3.22.1']
    for phase, arguments, timeout in [('licenses', ['--licenses'], 180),
                                      ('install', ['--install', *requested], 900)]:
        print(f'Running SDK manager {phase} with explicit stdin (timeout {timeout}s).', flush=True)
        receipt = {'stage': phase, 'requested_packages': requested, 'explicit_stdin': True}
        (report / 'android-packages.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
        result = subprocess.run(command + arguments, input='y\n' * 256,
                                capture_output=True, text=True, encoding='utf-8',
                                errors='replace', timeout=timeout)
        output = result.stdout + result.stderr
        (report / f'android-{phase}.txt').write_text(output, encoding='utf-8')
        print(output[-1800:], flush=True)
        if result.returncode:
            raise RuntimeError(f'Android SDK manager {phase} failed with exit {result.returncode}.')
    required = ['ndk/27.0.12077973/build/cmake/android.toolchain.cmake',
                'cmake/3.22.1/bin/cmake.exe', 'cmake/3.22.1/bin/ninja.exe']
    missing = [relative for relative in required if not (sdk / relative).is_file()]
    if missing:
        raise RuntimeError('SDK manager did not install required files: ' + ', '.join(missing))
    receipt.update({'stage': 'ready', 'verified_files': required})
    (report / 'android-packages.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    print('Private Android SDK packages and executables verified.', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sdk-root', type=Path, required=True)
    parser.add_argument('--report-directory', type=Path, required=True)
    parser.add_argument('--install-packages', action='store_true')
    arguments = parser.parse_args()
    if arguments.install_packages:
        install_packages(arguments.sdk_root, arguments.report_directory)
    else:
        prepare(arguments.sdk_root, arguments.report_directory)
