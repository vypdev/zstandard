"""Download the reviewed Android tools into a fresh job-private Windows SDK."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
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


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sdk-root', type=Path, required=True)
    parser.add_argument('--report-directory', type=Path, required=True)
    arguments = parser.parse_args()
    prepare(arguments.sdk_root, arguments.report_directory)
