# Query: Confirm the database is up to date as of today (2026-05-26)

**Run time:** 2026-05-26 05:36 UTC
**Last unshelve:** 2026-05-20 22:49:41 UTC — instance has been continuously up for **5 days 6 hours** since the catch-up run on 2026-05-20.

---

## Bottom line

**Database is fully current.** Mesonet ingestion is lagging by 16 minutes — normal for a 15-min cron schedule. No backlog, no recent errors, all materialized views refreshing on schedule, and disk usage is stable.

---

## 1. Mesonet measurements — HEALTHY

| Metric | Value |
|--------|-------|
| Latest timestamp | 2026-05-26 05:20:00 UTC |
| Lag from `now()` | **16 min** (cron fires every 15 min — normal) |
| Total rows | **1,004,530,125** (just crossed 1B) |

## 2. Ingestion-log audit, last 7 days

| job_type | status | runs | first run | last run |
|----------|--------|------|-----------|----------|
| update | success | 507 | 2026-05-20 22:57 | 2026-05-26 05:30 |
| update | error | **1** | 2026-05-22 15:00 | 2026-05-22 15:00 |
| refresh_views | success | 21 | 2026-05-21 00:00 | 2026-05-26 00:00 |

**One transient error** on 2026-05-22 15:00 — DNS/network blip on `api.hcdp.ikewai.org` (`HTTPSConnectionPool ... Max retries exceeded`). The next 15-min cron tick recovered automatically because the ingester resumes from `MAX(timestamp)` in the DB rather than a stored marker. **No data was lost.**

507 successful runs over 5d 6h = ~95 runs/day = ~4 runs/hour — exactly what `*/15` expects.

## 3. Daily mesonet row counts (last 9 days)

| Day (HST) | Rows | Active stations |
|-----------|------|----------------|
| 2026-05-17 | 207,929 | 75 | (partial — pre-shelve cutoff) |
| 2026-05-18 | 1,163,039 | 76 | (recovered by catch-up) |
| 2026-05-19 | 1,160,434 | 76 |
| 2026-05-20 | 1,081,652 | 76 |
| 2026-05-21 | 1,043,074 | 76 |
| 2026-05-22 | 1,043,743 | 75 |
| 2026-05-23 | 1,040,247 | 74 |
| 2026-05-24 | 1,041,868 | 75 |
| 2026-05-25 | 846,046 | 75 | (in progress — query ran early UTC 5/26) |

~1.04-1.16M rows/day across 74-76 active stations is the expected baseline. No drop-outs or anomalies in daily volume.

## 4. Per-station freshness — 2 stale, 25 never reported (both pre-existing)

**Stale (>7 days since last reading):**

| station | name | island | last reading | lag |
|---------|------|--------|--------------|-----|
| 0532 | Pālolo Mauka | Oahu | 2026-04-26 14:10 | 29 days |
| 0245 | Kīpuka Nui | Hawaii | 2026-01-20 16:20 | 125 days |

Both are **known long-term station outages** documented in the 2026-04-29 diagnostic report. Neither is a new problem from this shelve event.

**Never reported (25 stations):** planned/not-yet-deployed sites — `0203 ʻŌlaʻa, 0215 Hakalau, 0216 Punahoa, 0223 Nāʻōhuleʻelua, 0224 Puʻuheʻewai, 0225 Alaekila, 0232 Kahilipalinui, 0233 Ka Lae, 0234 Kahuku, 0247 Kipahoehoe, 0248 Kauhuku Mauka, 0259 Puʻuoli, 0260 Puanui, 0162 Treeline, 0164 Big Bog, 0413 ʻUalapuʻe, 0414 Pēpēʻōpae, 0522 Palikea, 0542 Poamoho Connex LZ, 0543 Poamoho Summit, 0544 Waiawa, 0604 Upper Limahuli, 0631 Polihale, 0632 Kitano Reservoir, 0642 Powerline Trail`.

Same set as the original network-health inventory.

## 5. Materialized views — refreshed every 6h on schedule

| view | latest date | rows |
|------|-------------|------|
| `mv_daily_station_summary_qc` | 2026-05-25 | 72,350 |
| `mv_daily_station_summary_raw` | 2026-05-25 | 72,350 |
| `mv_monthly_station_summary_qc` | 2026-05-01 | 2,459 |
| `mv_monthly_station_summary_raw` | 2026-05-01 | 2,459 |

Monthly views correctly cap at May (first-of-month aggregate; June would appear after 2026-06-01 completes). Daily views are 1 day behind today, which is normal — the last `refresh_views` ran at 2026-05-26 00:00 UTC, picking up data through end-of-day 2026-05-25.

Last 5 `refresh_views` runs all `success`, each ~31 min. The cron is `0 */6 * * *` — 4 runs per day.

## 6. Disk usage

| Volume | Size | Used | Free | % |
|--------|------|------|------|---|
| `/media/volume/hcdp_postgres_db` (primary) | 246 GB | 196 GB | 51 GB | 80% |
| `/media/volume/hcdp_postgres_db_2` (raster cache) | 738 GB | 825 MB | 737 GB | 1% |

Primary at 80% — same level as before. The growth trajectory is ~6 GB/week of new mesonet data; should be fine until volume upgrade is needed in 2-3 months at current rate.

## 7. Historical station values — known publication-lag

| Metric | Value |
|--------|-------|
| Latest month | 2026-03-01 |
| Rows | 228,414 |
| Distinct stations | 762 |

**Historical data is ~2 months behind by HCDP's own publication schedule.** This is the documented gap (no cron exists for `--historical`; last manual run was 2026-04-09). The 2-month lag = HCDP publication lag (~1 month) + lack of scheduled refresh. **Not a freshness regression from this shelve event** — predates it.

## 8. Services

- `postgresql@16-main` cluster: online (port 5432)
- `hcdp-raster-service.service`: active (running). `GET /health` returns `{"status":"ok"}`.

---

## Verdict

**Fully up to date.** The 2026-05-20 catch-up recovered 6.75M rows in a single 15-min run; cron has continued cleanly since then with 507 successful runs and 1 self-recovered transient error. Materialized views are tracking on their 6-hour schedule. No new stale stations introduced by the shelve event.

**Pre-existing items unchanged from prior audits** (not caused by the shelve):
- Stations 0245 and 0532 still offline (long-term station failures)
- Historical_station_values lagging by ~2 months (no cron — should add one if monthly data matters)
- Primary disk at 80% (planned upgrade)
- `flock` not yet added to `run.sh` (the cron-overlap fix from the 2026-05-20 conversation — still recommended but not blocking)
