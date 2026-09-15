# Copyright (c) 2026, PostgreSQL Global Development Group
#
# CI-only module for CF #6819 v9: publishes Extension/HarnessOuterWait,
# logs from inside that region, then sleeps.  Not part of the patch series.

harness_outer_wait_sources = files(
  'harness_outer_wait.c',
)

if host_system == 'windows'
  harness_outer_wait_sources += rc_lib_gen.process(win32ver_rc, extra_args: [
    '--NAME', 'harness_outer_wait',
    '--FILEDESC', 'harness_outer_wait - nested wait event harness',])
endif

harness_outer_wait = shared_module('harness_outer_wait',
  harness_outer_wait_sources,
  kwargs: pg_test_mod_args,
)
test_install_libs += harness_outer_wait
