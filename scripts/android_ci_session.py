#!/usr/bin/env python3
"""Lease the host's shared Android SDK/ADB/emulator for one complete CI session."""

import fcntl
import os
from pathlib import Path
import signal
import stat
import subprocess
import sys
import time

HANDOFF = 'ZSTANDARD_ANDROID_SESSION_PARENT'


def run_session(command, lock_path, wait_seconds=3600):
    flags = os.O_CREAT | os.O_RDWR | getattr(os, 'O_NOFOLLOW', 0)
    descriptor = os.open(lock_path, flags, 0o600)
    with os.fdopen(descriptor, 'a') as lease:
        information = os.fstat(lease.fileno())
        if not stat.S_ISREG(information.st_mode) or information.st_uid != os.getuid():
            raise PermissionError('Android CI lease must be an owned regular file.')
        deadline = time.monotonic() + wait_seconds
        waiting = False
        while True:
            try:
                fcntl.flock(lease, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() >= deadline:
                    print('Timed out waiting for the shared Android CI session.', file=sys.stderr)
                    return 75
                if not waiting:
                    print('Waiting for the shared Android CI session.', flush=True)
                    waiting = True
                time.sleep(min(0.1, max(0, deadline - time.monotonic())))
        print('Acquired the shared Android CI session.', flush=True)
        child = None
        pending = []

        def forward(signum, _frame):
            if child is None:
                pending.append(signum)
                return
            try:
                os.killpg(child.pid, signum)
            except ProcessLookupError:
                pass

        signals = [signal.SIGINT, signal.SIGTERM, signal.SIGHUP]
        previous = {number: signal.signal(number, forward) for number in signals}
        try:
            # The lease stays in this parent. SDK daemons must never inherit it.
            child = subprocess.Popen(command, start_new_session=True, close_fds=True,
                                     env={**os.environ, HANDOFF: str(os.getpid())})
            for number in pending:
                forward(number, None)
            result = child.wait()
            return result if result >= 0 else 128 - result
        finally:
            if child is not None and child.poll() is None:
                forward(signal.SIGTERM, None)
                try:
                    child.wait(timeout=30)
                except subprocess.TimeoutExpired:
                    forward(signal.SIGKILL, None)
                    child.wait()
            for number, handler in previous.items():
                signal.signal(number, handler)


def main(arguments):
    if not arguments:
        raise ValueError('An Android CI session command is required.')
    wait_seconds = int(os.environ.get('ANDROID_CI_LOCK_TIMEOUT_SECONDS', '3600'))
    if not 1 <= wait_seconds <= 7200:
        raise ValueError('ANDROID_CI_LOCK_TIMEOUT_SECONDS must be between 1 and 7200.')
    # Runner services share this user-level host resource, regardless of repo,
    # workflow, branch or their separate RUNNER_TEMP directories.
    directory = Path('/tmp') / f'zstandard-android-ci-{os.getuid()}'
    directory.mkdir(mode=0o700, exist_ok=True)
    information = directory.lstat()
    if not stat.S_ISDIR(information.st_mode) or information.st_uid != os.getuid() \
            or stat.S_IMODE(information.st_mode) & 0o077:
        raise PermissionError('Android CI lease directory must be private and owned.')
    return run_session(arguments, directory / 'session.lock', wait_seconds)


if __name__ == '__main__':
    try:
        raise SystemExit(main(sys.argv[1:]))
    except (OSError, ValueError) as error:
        print(f'Android CI session failed: {error}', file=sys.stderr)
        raise SystemExit(1)
