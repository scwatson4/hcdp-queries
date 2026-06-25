# What `REFRESH MATERIALIZED VIEW CONCURRENTLY` actually does (and why it spills 60+ GB)

**Date:** 2026-06-25
**Scope:** explainer, prompted by the manual refresh of `mv_daily_station_summary_qc` taking 10+
minutes and growing `pgsql_tmp` past 60 GB. Grounded in this instance's live state. Read-only.

---

## TL;DR

The 60+ GB of temp is **not missing data being backfilled** — station 0533 added only 15 of the
view's 74,620 rows. A `REFRESH` rebuilds the **entire** view from scratch by re-aggregating all
**~1.03 billion** `mesonet_measurements` rows, and the grouping of a billion rows under an 8 MB
`work_mem` budget spills tens of GB of transient sort data to disk. The result is 14 MB; the 60+ GB
is scratch that's discarded when it finishes.

| | |
|---|---|
| Base rows re-aggregated | 1,035,043,938 (~1.03 B) |
| Rows in the final view | 74,620 |
| View size on disk | 14 MB |
| `work_mem` (this refresh) | 8 MB |
| `pgsql_tmp` peak observed | ~61 GB |
| Backends | 1 leader + 2 parallel workers |

---

## What a materialized view is

A **regular view** is a saved query — re-run on every `SELECT`. A **materialized view** stores the
query's *result* physically on disk. `mv_daily_station_summary_qc` keeps 74,620 pre-computed daily
rows so a "driest stations" query reads 14 MB instantly instead of re-scanning a billion
measurements each time. The tradeoff: the stored copy goes stale and must be *refreshed*.

## What `REFRESH` does — the defining query

`REFRESH` re-runs the view's defining query and replaces the stored contents. The plan (from
`EXPLAIN`, not executed) is:

```
Finalize GroupAggregate
  Group Key: station_id, date(timestamp AT TIME ZONE 'Pacific/Honolulu')
  -> Gather Merge (Workers Planned: 2)
       -> Sort  (Sort Key: station_id, date_hst)
            -> Partial HashAggregate
                 -> Parallel Seq Scan on mesonet_measurements
```

Step by step:
1. **Parallel Seq Scan** of all 1.03 B `mesonet_measurements` rows (1 leader + 2 workers).
2. For each row, convert `timestamp` → HST date and evaluate `CASE` expressions that route the value
   into the right metric (rainfall = `RF_1_Tot300s`, temp = `Tair%`, RH = `RH%Avg%`, …).
3. **HashAggregate → Sort → Gather Merge → Finalize GroupAggregate**: group every row by
   `(station_id, date_hst)` and compute per-day min/max/avg/sum. **This grouping is the spill** —
   a billion rows can't be grouped in 8 MB of `work_mem`, so the intermediate set goes to
   `pgsql_tmp` on disk (observed live as `BufFileRead` IO waits).
4. Join grouped rows to `mesonet_stations` for name/island → 74,620 final rows.

## What `CONCURRENTLY` adds (and why it's heavier)

A **plain** `REFRESH MATERIALIZED VIEW` takes an `ACCESS EXCLUSIVE` lock: it truncates the MV and
refills it, **blocking every reader** for the whole ~10-minute run (the chatbot's ranking queries
would hang).

`REFRESH … CONCURRENTLY` never blocks readers. To do that it can't truncate-and-refill; it does a
**diff-and-patch**:
1. Run the defining query and write the **entire fresh result into a new temporary table** (the
   heavy billion-row aggregation above).
2. **Diff** that temp table against the current MV via a `FULL OUTER JOIN` matched on the unique key.
   *This is why a `CONCURRENTLY` refresh requires a unique index* (`idx_mv_daily` on
   `(station_id, date_hst)`) — it's how Postgres pairs an old row with its new counterpart to see
   what changed.
3. Apply **only the deltas** — `INSERT` new rows (e.g. 0533's 15 days), `UPDATE` changed, `DELETE`
   removed — against the live MV under a light lock, so concurrent `SELECT`s keep working the whole
   time (seeing old data until the deltas land).
4. Drop the temp table — the ~61 GB of scratch vanishes.

So the price of "readers never block" is building a **complete second copy** and diffing it, instead
of overwriting — extra temp space and CPU. That is the heaviness.

## Why it failed before but not now

On the old `/dev/sdc` volume there were only 44 GB free; the spill needs 60+ GB, so it died fast
(~5 min) with `No space left on device`. After migrating PGDATA to `/dev/sdb` (483+ GB free), the
same spill fits and the refresh simply runs to completion — it's slow only because it grinds a
billion rows, not because anything is wrong.

## Why the 6-hourly cron refresh is lighter

`ingest.py`'s `refresh_views()` sets `work_mem = '4GB'` and disables parallel workers before
refreshing. A 4 GB memory budget keeps far more of the grouping in RAM (much less spill) than the
default **8 MB** used by an ad-hoc manual `REFRESH`. So the scheduled refresh is materially more
disk-efficient; the manual run observed here is the worst case for temp usage. A manual refresh
could match it with a session-level `SET work_mem='4GB'` — a tuning choice, unnecessary now that the
volume has ample headroom.

## After the daily view

Once the daily MV finishes, the **monthly** MV refreshes the same way — but it aggregates from the
small daily MV (74,620 rows), not the billion-row base table, so it completes in ~0.1 s.

## Provenance
Live state from `pg_stat_activity`, `pg_class`, `pg_get_viewdef`, `EXPLAIN (COSTS OFF)` (planned,
not executed), and `du` on `pgsql_tmp`. Read-only. Counts: 1,035,043,938 base rows; 74,620 MV rows;
14 MB MV; 8 MB `work_mem`; ~61 GB peak spill.
