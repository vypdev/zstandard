"""Reproduce Android source discovery with a real Windows-hosted NDK build."""

import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import shutil
import struct
import subprocess
import tarfile
import tempfile
import urllib.request


def run(command, report, *, expected_success=True, timeout=300):
    result = subprocess.run([str(part) for part in command], capture_output=True,
                            text=True, errors='replace', timeout=timeout)
    output = result.stdout + result.stderr
    report.write_text(output, encoding='utf-8')
    print(output[-8000:], flush=True)
    if expected_success and result.returncode:
        raise RuntimeError(f'{command[0]} failed; see {report.name}')
    return result.returncode, output


def sdk_tools(report):
    roots = [Path(value) for name in ['ANDROID_SDK_ROOT', 'ANDROID_HOME']
             if (value := os.environ.get(name))]
    if os.environ.get('LOCALAPPDATA'):
        roots.append(Path(os.environ['LOCALAPPDATA']) / 'Android/Sdk')
    roots += [Path.home() / 'Library/Android/sdk', Path.home() / 'Android/Sdk']
    sdk = next((root for root in roots if any((root / child).is_dir()
                for child in ['cmdline-tools', 'platform-tools', 'ndk'])), None)
    information = {'host': platform.system(), 'architecture': platform.machine(),
                   'sdk': str(sdk) if sdk else None,
                   'free_temporary_bytes': shutil.disk_usage(tempfile.gettempdir()).free}
    executable = '.exe' if os.name == 'nt' else ''
    ndks = sorted((sdk / 'ndk').iterdir(), reverse=True) if sdk and (sdk / 'ndk').is_dir() else []
    preferred = next((p for p in ndks if p.name == '27.0.12077973'), None)
    ndk = preferred or next((p for p in ndks if
                            (p / 'build/cmake/android.toolchain.cmake').is_file()), None)
    information['ndk'] = str(ndk) if ndk else None
    candidates = []
    if sdk:
        candidates.append(sdk / f'cmake/3.22.1/bin/cmake{executable}')
        if (sdk / 'cmake').is_dir():
            candidates += [p / f'bin/cmake{executable}'
                           for p in sorted((sdk / 'cmake').iterdir(), reverse=True)]
    if shutil.which('cmake'):
        candidates.append(Path(shutil.which('cmake')))
    if os.name == 'nt':
        for variable in ['ProgramFiles', 'ProgramFiles(x86)']:
            if os.environ.get(variable):
                candidates.append(Path(os.environ[variable]) / 'CMake/bin/cmake.exe')
        if os.environ.get('ProgramFiles(x86)'):
            vswhere = Path(os.environ['ProgramFiles(x86)']) / 'Microsoft Visual Studio/Installer/vswhere.exe'
            if vswhere.is_file():
                installations = json.loads(subprocess.check_output(
                    [str(vswhere), '-products', '*', '-format', 'json'], text=True))
                candidates += [Path(item['installationPath']) /
                               'Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe'
                               for item in installations]
    cmake = next((p for p in candidates if p.is_file()), None)
    information['cmake'] = str(cmake) if cmake else None
    ninja_candidates = [cmake.parent / ('ninja' + executable)] if cmake else []
    if cmake and os.name == 'nt':
        ninja_candidates.append(cmake.parent.parent.parent / 'Ninja/ninja.exe')
    if shutil.which('ninja'):
        ninja_candidates.append(Path(shutil.which('ninja')))
    ninja = next((p for p in ninja_candidates if p.is_file()), None)
    information['ninja'] = str(ninja) if ninja else None
    emulator = sdk / ('emulator/emulator' + executable) if sdk else None
    information['emulator_available'] = bool(emulator and emulator.is_file())
    if information['emulator_available']:
        result, _ = run([emulator, '-accel-check'], report / 'emulator-acceleration.txt',
                        expected_success=False, timeout=30)
        information['emulator_acceleration_check_exit'] = result
    (report / 'toolchain.json').write_text(json.dumps(information, indent=2), encoding='utf-8')
    print(json.dumps(information, indent=2), flush=True)
    if not all([sdk, ndk, cmake, ninja]):
        raise RuntimeError('An Android SDK, NDK, CMake and Ninja are required; see toolchain.json.')
    run([cmake, '--version'], report / 'cmake-version.txt')
    return ndk, cmake, ninja


def published_package(package, version, destination):
    def get(url):
        with urllib.request.urlopen(url, timeout=60) as response:
            return response.read()

    metadata = json.loads(get(f'https://pub.dev/api/packages/{package}/versions/{version}'))
    assert metadata['version'] == version and metadata['pubspec']['name'] == package
    archive = get(metadata['archive_url'])
    digest = hashlib.sha256(archive).hexdigest()
    assert digest == metadata['archive_sha256']
    destination.mkdir(parents=True)
    with tarfile.open(fileobj=io.BytesIO(archive), mode='r:gz') as tar:
        for member in tar:
            relative = Path(member.name)
            target = destination / relative
            if relative.is_absolute() or '..' in relative.parts or not target.resolve().is_relative_to(destination.resolve()):
                raise ValueError('Unsafe package archive member')
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True)
            elif member.isfile():
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(tar.extractfile(member).read())
            else:
                raise ValueError('Expected only regular package files and directories')
    return {'package': package, 'version': version, 'archive_sha256': digest}


def reproduce(version, report):
    ndk, cmake, ninja = sdk_tools(report)
    with tempfile.TemporaryDirectory(prefix='zstandard android windows ') as temporary:
        stage = Path(temporary)
        cache = stage / 'Pub cache/hosted/pub.dev'
        plugin = cache / f'zstandard_android-{version}'
        native = cache / f'zstandard_native-{version}'
        packages = [published_package('zstandard_android', version, plugin),
                    published_package('zstandard_native', version, native)]
        consumer = stage / 'separate consumer'
        configuration = consumer / '.dart_tool/package_config.json'
        configuration.parent.mkdir(parents=True)
        configuration.write_text(json.dumps({'configVersion': 2, 'packages': [
            {'name': 'zstandard_android', 'rootUri': plugin.as_uri() + '/', 'packageUri': 'lib/'},
            {'name': 'zstandard_native', 'rootUri': native.as_uri() + '/', 'packageUri': 'lib/'}
        ]}, indent=2), encoding='utf-8')
        common = [cmake, '-G', 'Ninja', '-S', plugin / 'zstd_build',
                  f'-DCMAKE_MAKE_PROGRAM={ninja}',
                  f'-DCMAKE_TOOLCHAIN_FILE={ndk / "build/cmake/android.toolchain.cmake"}',
                  '-DANDROID_ABI=arm64-v8a', '-DANDROID_PLATFORM=android-21',
                  '-DCMAKE_BUILD_TYPE=RelWithDebInfo']
        result, output = run(common + ['-B', stage / 'baseline'],
                             report / 'baseline-configure.txt', expected_success=False)
        if result == 0 or 'zstd source not found' not in output:
            raise RuntimeError('The expected source-discovery failure was not reproduced.')
        control = stage / 'explicit-root-control'
        run(common + ['-B', control, f'-DZSTD_ROOT={(native / "src/zstd").as_posix()}'],
            report / 'control-configure.txt')
        run([cmake, '--build', control, '--parallel', '2'], report / 'control-build.txt')
        library = control / 'libzstandard_android.so'
        data = library.read_bytes()
        assert data[:4] == b'\x7fELF' and struct.unpack_from('<H', data, 18)[0] == 183
        receipt = {'baseline_version': version, 'packages': packages,
                   'consumer_outside_cache': True, 'paths_contain_spaces': True,
                   'configuration': json.loads(configuration.read_text(encoding='utf-8')),
                   'baseline_missing_source_reproduced': True, 'explicit_root_control_build': True,
                   'android_abi': 'arm64-v8a', 'android_api': 21,
                   'control_library_sha256': hashlib.sha256(data).hexdigest()}
        (report / 'reproduction.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
        print('Reproduced the published package failure; explicit-root control built a real Android ARM64 library.', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline-version', default='1.5.3')
    parser.add_argument('--report-directory', type=Path, required=True)
    arguments = parser.parse_args()
    arguments.report_directory.mkdir(parents=True, exist_ok=True)
    reproduce(arguments.baseline_version, arguments.report_directory)
