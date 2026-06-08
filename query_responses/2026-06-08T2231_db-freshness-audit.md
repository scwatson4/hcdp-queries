# Query: Is the database up to date? Check for any errors or data gaps.

**Run time:** 2026-06-08 22:31 UTC
**Last audit:** 2026-05-26 05:36 UTC (~13 days ago)
**Uptime since last unshelve:** 18 days 23 hours (since 2026-05-20 22:49 UTC)

---

## Bottom line

**Database is up to date and healthy.** Latest mesonet timestamp is 2026-06-08 22:20 UTC (11 min lag — normal). Six transient HCDP API errors over the last 14 days, all self-recovered by the next cron tick — no data lost. One stuck `refresh_views` log row from June 3 is a log-hygiene artifact, not a data problem. No new station outages.

---

## 1. Headline

| Metric | Value |
|--------|-------|
| Latest mesonet timestamp | 2026-06-08 22:20 UTC |
| Lag from `now()` | **11 min** (15-min cron — normal) |
| Total rows | **1,018,800,477** |
| Postgres cluster | online |
| `hcdp-raster-service` | active, `/health` returns OK |

## 2. Ingestion audit, last 14 days

| job_type | status | runs | first run | last run |
|----------|--------|------|-----------|----------|
| update | success | **1,338** | 2026-05-25 22:45 | 2026-06-08 22:30 |
| update | error | **6** | 2026-05-27 04:15 | 2026-06-04 02:00 |
| refresh_views | success | 55 | 2026-05-26 00:00 | 2026-06-08 18:00 |
| refresh_views | running (stuck) | 1 | 2026-06-03 06:00 | 2026-06-03 06:00 |

**Update success rate: 99.55%.**

## 3. All errors — transient HCDP-side failures

| id | when | error |
|---|---|---|
| 6384 | 2026-06-04 02:00 | 504 Server Error: Gateway Time-out |
| 6383 | 2026-06-04 01:45 | 504 Server Error: Gateway Time-out |
| 6321 | 2026-06-03 11:00 | DNS/network: Max retries exceeded |
| 6259 | 2026-06-02 20:00 | 502 Server Error: Bad Gateway |
| 6172 | 2026-06-01 23:15 | 504 Server Error: Gateway Time-out |
| 5593 | 2026-05-27 04:15 | DNS/network: Max retries exceeded (`/stationMonitor` endpoint) |

The June 1–4 cluster (four errors over four days) suggests the HCDP API itself had a rough patch midweek. Each failure was a single 15-min cron tick; the next tick recovered from `MAX(timestamp)` in the database. **No data was permanently lost.**

## 4. One stuck `refresh_views` log entry (cosmetic)

| id | job_type | started | status |
|---|---|---|---|
| 6300 | refresh_views | 2026-06-03 06:00 | running (stale, 5+ days) |

Looking at the runs immediately around it: the 00:00 succeeded, the 06:00 stuck, the 12:00 succeeded again. **The matview refresh process died without updating its log row** — same orphaned-`running` pattern observed in the April 2026 entries from earlier audits. The materialized views themselves are still up to date through the 2026-06-08 18:00 successful refresh (4 h ago).

## 5. Daily mesonet row counts — no gaps

| Day (HST) | Rows | Active stations |
|-----------|------|----------------|
| 2026-05-24 | 493,686 | 75 (partial — query window cutoff) |
| 2026-05-25 | 1,038,451 | 75 |
| 2026-05-26 | 1,040,514 | 76 |
| 2026-05-27 | 1,046,545 | 76 |
| 2026-05-28 | 1,048,495 | 75 |
| 2026-05-29 | 1,048,969 | 75 |
| 2026-05-30 | 1,049,359 | 76 |
| 2026-05-31 | 1,045,472 | 76 |
| 2026-06-01 | 1,034,013 | 75 |
| 2026-06-02 | 1,030,211 | 76 |
| 2026-06-03 | 1,030,515 | 75 |
| 2026-06-04 | 1,046,153 | 76 |
| 2026-06-05 | 1,036,895 | 76 |
| 2026-06-06 | 1,041,245 | 76 |
| 2026-06-07 | 1,042,766 | 75 |
| 2026-06-08 | 536,795 | 76 (partial — query ran mid-day) |

All 14 complete days within the window are **~1.03–1.05M rows / 74–76 stations** — entirely normal. The single-day errors (June 1, 2, 3, 4) didn't depress those days' row counts — the next cron tick caught up cleanly. **No day is conspicuously low.**

## 6. Materialized views

| view | latest date | rows |
|---|---|---|
| `mv_daily_station_summary_qc` | 2026-06-08 | 73,408 |
| `mv_daily_station_summary_raw` | 2026-06-08 | 73,408 |
| `mv_monthly_station_summary_qc` | 2026-06-01 | 2,535 |
| `mv_monthly_station_summary_raw` | 2026-06-01 | 2,535 |

Daily views are current through today. Monthly views correctly cap at 2026-06-01 — June's monthly aggregate won't materialize until the month closes. Last 10 `refresh_views` runs all `success`, each ~31 min.

## 7. Stale stations — unchanged from 2026-05-26 audit

| station | name | island | last reading | lag |
|---|---|---|---|---|
| 0245 | Kīpuka Nui | Hawaiʻi | 2026-01-20 16:20 | 139 days |
| 0532 | Pālolo Mauka | Oʻahu | 2026-04-26 14:10 | 43 days |

Both are **known long-term station outages** from earlier audits. No new stale stations have appeared.

## 8. Disk

| Volume | Size | Used | Free | % |
|--------|------|------|------|---|
| `/media/volume/hcdp_postgres_db` (primary) | 246 GB | 199 GB | 48 GB | 81% |
| `/media/volume/hcdp_postgres_db_2` (raster cache) | 738 GB | 825 MB | 737 GB | 1% |

Primary up 3 GB since the 2026-05-26 audit (80% → 81%). Growth rate ~1 GB/week — sustainable for the next 6–12 months at current pace.

## 9. Historical_station_values — unchanged stale

| Metric | Value |
|--------|-------|
| Latest month | 2026-03-01 |
| Rows | 228,414 |
| Distinct stations | 762 |

Still at 2026-03 — last manual `--historical` run was 2026-04-09 (no cron exists for this job). Three months behind by HCDP's own publication schedule + lack of scheduled refresh. Pre-existing item from earlier audits.

---

## Verdict

**Up to date and healthy.**

- No new data gaps
- No new station outages
- 6 transient HCDP API errors recovered cleanly via the existing resume-from-`MAX(timestamp)` design
- 1 stuck `refresh_views` log entry (cosmetic; doesn't affect matview data)
- Disk growth on track

**Pre-existing items still outstanding from prior audits** (not caused by this audit window):

- Stations 0245 and 0532 still offline (long-term failures)
- `historical_station_values` still 3 months stale (no cron — needs a scheduled `--historical` job if monthly aggregates matter for ongoing analysis)
- Primary disk at 81% (volume expansion will be needed eventually)
- `flock` not yet added to `run.sh` (still recommended to prevent the concurrent-cron-fire after long gaps that wastes API calls)
