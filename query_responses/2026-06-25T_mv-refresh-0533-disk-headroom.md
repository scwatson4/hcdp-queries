# Manual QC-view refresh for station 0533: succeeded (via cron), and surfaced a disk-headroom issue

**Date:** 2026-06-25
**Scope:** authorized refresh-and-verify of the two QC materialized views so station 0533's data
appears in rankings. Read + `REFRESH MATERIALIZED VIEW` + verification SELECTs only. No schema/data
rows, raster service, cron, firewall, VNC, or Postgres-config change. No secrets printed. When the
refresh failed unexpectedly, I stopped and reported rather than improvising a fix.

---

## Outcome: 0533 is now in the rankings

| view | before | after | first day | last day |
|---|---|---|---|---|
| `mv_daily_station_summary_qc` | 0 | **15** | 2026-06-10 | 2026-06-24 |
| `mv_monthly_station_summary_qc` | 0 | **1** | — | — |

**Sanity (matches the windward-Oʻahu expectation):** 0533 "Maunawili Pālāwai" ranks **39 of 77**
stations for June 2026 by average daily rate (3.49 mm/day; 52.3 mm / 2.06 in over **15 reporting
days**) — mid-pack, **not** near the driest end. It isn't at the extreme wet end only because June
is dry-season and it has a 15-day partial sample (started 2026-06-10); `days_reporting = 15` surfaces
that. No false-driest thin-sample artifact.

## The manual refresh itself FAILED — what actually happened

- **My `REFRESH … CONCURRENTLY mv_daily_station_summary_qc` ran 5 min and died** with
  `ERROR: could not write to file "base/pgsql_tmp/...": No space left on device`, then rolled back
  (leaving the old MV intact). The monthly refresh returned in 139 ms but read the unchanged daily,
  so it carried no new data. Immediately after Step 2, 0533 was still 0/0.
- **Root cause = collision + marginal disk.** The 6-hourly cron `refresh_views` job **8468 had
  started at 00:00:01** and was rebuilding the *same* daily MV when my manual refresh launched. Two
  simultaneous full rebuilds — each sorting the **202 GB** `mesonet_measurements` table with large
  `pgsql_tmp` temp-spill — exhausted the volume's ~44 GB free space.
- **What fixed it:** once my failed attempt freed its temp files, cron job 8468 finished **alone**
  at **00:32:23 (status: success)** and surfaced 0533. No retry from me was needed.
- Neither `CONCURRENTLY` fallback was triggered; the only failure was disk, not a missing unique
  index. The QC layer was never broken — the daily MV was already current to 2026-06-24 and recent
  scheduled refreshes all succeeded.

## Storage — how much is left

| Volume | Mount | Size | Used | **Free** | Use% |
|---|---|---|---|---|---|
| `/dev/sdc` | `/media/volume/hcdp_postgres_db` (**Postgres data**) | 246 G | 202 G | **44 G** | **83%** |
| `/dev/sdb` | `/media/volume/hcdp_postgres_db_2` (rasters) | 738 G | 1 G | **737 G** | **1%** |
| `/dev/sda1` | `/` (root) | 58 G | 19 G | **39 G** | 33% |

The DB is **202 GB**, essentially all `mesonet_measurements` (heap + its 81 GB `idx_meas_upsert`
and 44 GB `idx_meas_var_station_ts` indexes). It lives on `/dev/sdc`, which is 83% full. Meanwhile
**`/dev/sdb` has 737 GB free** — the instance is not short on storage overall; the temp-spill squeeze
is confined to the data volume.

## The standing risk
A *single* daily-MV refresh currently fits in the ~44 GB free, but **two at once do not** (proven
today), and as `mesonet_measurements` grows the temp-spill of even a single refresh will keep
creeping toward the limit. Left unaddressed, a future scheduled refresh could fail and the QC views
would silently go stale.

## Mitigations (out of scope here — need authorization)
1. **Cheapest: redirect Postgres temp spill to the near-empty volume.** Point `temp_tablespaces`
   (or the `pgsql_tmp` location) at a tablespace on `/dev/sdb` (737 GB free). This removes the
   refresh-temp squeeze without expanding `/dev/sdc`.
2. **Avoid overlap:** never run a manual refresh while the 00:00/06:00/12:00/18:00 cron
   `refresh_views` is active (a single refresh fits; concurrent ones don't).
3. **Longer-term:** expand `/dev/sdc`, and/or review the 81 GB + 44 GB measurement indexes for
   redundancy.

## What I did NOT do
No retry, no freeing disk, no killing the cron job, no config change — per the stop-and-report scope.

## Provenance
DB: `mv_daily_station_summary_qc`, `mv_monthly_station_summary_qc`, `mesonet_measurements`,
`ingestion_log`, `pg_stat_activity`, `pg_class`. Disk: `df` on the instance. Read + two
`REFRESH MATERIALIZED VIEW CONCURRENTLY` statements (one failed on disk, one succeeded) + verify
SELECTs. 0533 ultimately surfaced via the scheduled cron refresh (job 8468), not a manual retry.
