"""Run the existing unit suites against local packages and a real Linux plugin."""

import os
from pathlib import Path
import platform
import stat
import subprocess
import sys
import tempfile


PACKAGES = ['zstandard', 'zstandard_platform_interface', 'zstandard_android',
            'zstandard_ios', 'zstandard_macos', 'zstandard_linux',
            'zstandard_windows', 'zstandard_web', 'zstandard_cli']
OVERRIDDEN = [package for package in PACKAGES
              if package != 'zstandard_platform_interface']


def run(command, directory, environment):
    return subprocess.run(command, cwd=directory, env=environment,
                          check=True).returncode


def run_suite(root):
    root = root.resolve()
    environment = dict(os.environ)
    snapshots = {}
    generated = {}
    failed = False
    try:
        # Preserve authored local overrides; the helper also prepares examples.
        for package in OVERRIDDEN:
            folders = [root / package]
            if package not in ['zstandard', 'zstandard_cli']:
                folders.append(root / package / 'example')
            if package == 'zstandard_android':
                folders.append(root / package / 'example_legacy')
            for folder in folders:
                if not folder.is_dir():
                    continue
                path = folder / 'pubspec_overrides.yaml'
                if not folder.resolve().is_relative_to(root) or path.is_symlink():
                    raise ValueError('Unsafe local override path; no source was changed.')
                if path.exists() and not path.is_file():
                    raise ValueError('Local override must be a regular file.')
                snapshots[path] = (path.read_bytes(), stat.S_IMODE(path.stat().st_mode)) if path.exists() else None

        for package in OVERRIDDEN:
            if not (root / package).is_dir():
                continue
            try:
                run(['dart', str(root / 'scripts/create_local_overrides.dart'), package], root, environment)
            finally:
                # Capture helper output even when it fails after a partial write.
                for path in snapshots:
                    if path.relative_to(root).parts[0] == package and path.is_file() and not path.is_symlink():
                        generated[path] = path.read_bytes()

        for package in PACKAGES:
            folder = root / package
            if not folder.is_dir():
                print(f'Skip {package} (not found)', flush=True)
                continue
            print(f'---- Testing {package} ----', flush=True)
            sdk = 'dart' if package == 'zstandard_cli' else 'flutter'
            try:
                run([sdk, 'pub', 'get', '--no-example'], folder, environment)
                if package == 'zstandard_linux' and platform.system() == 'Linux':
                    example = folder / 'example'
                    run(['flutter', 'pub', 'get', '--no-example'], example, environment)
                    run(['flutter', 'build', 'linux', '--debug', '--no-pub'], example, environment)
                    architecture = {'x86_64': 'x64', 'aarch64': 'arm64', 'arm64': 'arm64'}.get(platform.machine())
                    if architecture is None:
                        raise ValueError('Unsupported Linux test architecture.')
                    libraries = example / 'build/linux' / architecture / 'debug/bundle/lib'
                    if not (libraries / 'libzstandard_linux_plugin.so').is_file():
                        raise ValueError('The Linux build did not produce its actual test plugin.')
                    environment['LD_LIBRARY_PATH'] = str(libraries) + (os.pathsep + environment['LD_LIBRARY_PATH'] if environment.get('LD_LIBRARY_PATH') else '')
                command = [sdk, 'test'] + ([] if sdk == 'dart' else ['--no-pub'])
                run(command, folder, environment)
                print(f'OK {package}', flush=True)
            except (subprocess.CalledProcessError, OSError, ValueError) as error:
                print(f'FAILED {package}: {error}', file=sys.stderr, flush=True)
                failed = True
    except (subprocess.CalledProcessError, OSError, ValueError) as error:
        print(f'Unit test preparation failed: {error}', file=sys.stderr, flush=True)
        failed = True
    finally:
        for index, (path, original) in enumerate(snapshots.items()):
            expected = generated.get(path)
            if expected is None:
                continue
            if path.is_symlink() or not path.is_file() or path.read_bytes() != expected:
                failed = True
                print(f'An override changed during testing; retaining it: {path}', file=sys.stderr)
                if original is not None:
                    backup = Path(tempfile.mkdtemp(prefix='zstandard-unit-override-recovery-')) / f'{index}.yaml'
                    backup.write_bytes(original[0])
                    backup.chmod(original[1])
                    print(f'Original override retained at {backup}', file=sys.stderr)
                continue
            if original is None:
                path.unlink()
            else:
                path.write_bytes(original[0])
                path.chmod(original[1])
    print('One or more packages had test failures.' if failed else 'All tests passed.', flush=True)
    return int(failed)


if __name__ == '__main__':
    sys.exit(run_suite(Path(__file__).resolve().parents[1]))
