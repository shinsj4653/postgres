/*
 * harness_outer_wait.c
 *
 * Reproduces the scenario Nikolay Samokhvalov described on-thread
 * (2026-09-15): publish a custom wait event, emit a LOG message from inside
 * that region, then keep waiting.  An observer sampling pg_stat_activity
 * after the log call returns should still see the outer event.
 */
#include "postgres.h"

#include "fmgr.h"
#include "utils/wait_event.h"

PG_MODULE_MAGIC;

PG_FUNCTION_INFO_V1(harness_wait);

Datum
harness_wait(PG_FUNCTION_ARGS)
{
	int32		secs = PG_GETARG_INT32(0);
	uint32		outer = WaitEventExtensionNew("HarnessOuterWait");

	pgstat_report_wait_start(outer);
	ereport(LOG, (errmsg("harness: logging from inside HarnessOuterWait")));
	pg_usleep((long) secs * 1000000L);
	pgstat_report_wait_end();

	PG_RETURN_VOID();
}
