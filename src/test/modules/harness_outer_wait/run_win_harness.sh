#!/usr/bin/env bash
# Runs on a windows-2022 GitHub Actions runner under `shell: bash` (Git Bash).
#
# Expects postgres installed at $GITHUB_WORKSPACE/pginst and the harness DLL
# built at build/src/test/modules/harness_outer_wait/harness_outer_wait.dll.
# For each log destination: start a throwaway cluster, run harness_wait(8)
# in one session (publish Extension/HarnessOuterWait, ereport(LOG), sleep),
# sample pg_stat_activity from another session 3 s later.  Exit 1 unless
# every sample still shows the outer event after the log call returned.
set -euo pipefail

WS=$(cygpath -u "$GITHUB_WORKSPACE")
PGBIN="$WS/pginst/bin"
DLL_WIN=$(cygpath -m "$WS/build/src/test/modules/harness_outer_wait/harness_outer_wait.dll")
DATA_WIN=$(cygpath -m "$WS/pgdata")
PORT=5599
export PGUSER=postgres

test -f "$WS/build/src/test/modules/harness_outer_wait/harness_outer_wait.dll" \
  || { echo "harness DLL not found"; exit 1; }

"$PGBIN/initdb" -D "$DATA_WIN" -U postgres -A trust --no-locale -E UTF8 >/dev/null
cp "$WS/pgdata/postgresql.conf" "$WS/pgdata/postgresql.conf.orig"

fail=0
run_case () {
  local tag=$1 name=$2; shift 2
  cp "$WS/pgdata/postgresql.conf.orig" "$WS/pgdata/postgresql.conf"
  {
    echo "port = $PORT"
    echo "log_min_messages = log"
    for l in "$@"; do echo "$l"; done
  } >> "$WS/pgdata/postgresql.conf"

  "$PGBIN/pg_ctl" -D "$DATA_WIN" -l "$(cygpath -m "$WS/server-$tag.log")" -w start >/dev/null
  "$PGBIN/psql" -qX -p $PORT -d postgres -c \
    "CREATE OR REPLACE FUNCTION harness_wait(int) RETURNS void AS '$DLL_WIN', 'harness_wait' LANGUAGE C STRICT;"

  "$PGBIN/psql" -qX -p $PORT -d postgres \
    -c "SET application_name = harness; SELECT harness_wait(8);" >/dev/null 2>&1 &
  sleep 3
  local out
  out=$("$PGBIN/psql" -qX -At -p $PORT -d postgres -c \
    "SELECT state, coalesce(wait_event_type,'NULL'), coalesce(wait_event,'NULL')
       FROM pg_stat_activity WHERE application_name = 'harness'")
  printf 'v9  %-32s -> %s\n' "$name" "$out"
  case "$out" in
    *"|Extension|HarnessOuterWait") ;;
    *) fail=1 ;;
  esac
  wait
  "$PGBIN/pg_ctl" -D "$DATA_WIN" -m fast -w stop >/dev/null
}

run_case eventlog  "eventlog"                       "log_destination = 'eventlog'" "logging_collector = off"
run_case stderr    "stderr, logging_collector=off"  "log_destination = 'stderr'"   "logging_collector = off"
run_case collector "stderr, logging_collector=on"   "log_destination = 'stderr'"   "logging_collector = on"

echo "--- expected on v9: every row ends in |Extension|HarnessOuterWait (v8 would show |NULL|NULL)"
exit $fail
