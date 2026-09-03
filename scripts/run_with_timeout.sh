#!/usr/bin/env bash

# Run a command with a portable Bash watchdog. This is used on macOS runners,
# where GNU coreutils' `timeout` is not guaranteed to be installed.

set -u

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <timeout-seconds> <command> [args...]" >&2
  exit 2
fi

timeout_seconds="$1"
shift

if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || (( timeout_seconds == 0 )); then
  echo "Timeout must be a positive number of seconds: ${timeout_seconds}" >&2
  exit 2
fi

"$@" &
command_pid=$!

(
  sleep "$timeout_seconds"
  if kill -0 "$command_pid" >/dev/null 2>&1; then
    echo "Command exceeded ${timeout_seconds}s; terminating it." >&2
    kill -TERM "$command_pid" >/dev/null 2>&1 || true
    sleep 5
    kill -KILL "$command_pid" >/dev/null 2>&1 || true
  fi
) &
watchdog_pid=$!

set +e
wait "$command_pid"
command_status=$?
set -e

kill "$watchdog_pid" >/dev/null 2>&1 || true
wait "$watchdog_pid" >/dev/null 2>&1 || true

if (( command_status == 143 || command_status == 137 )); then
  exit 124
fi
exit "$command_status"
