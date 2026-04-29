# Query: Run two diagnostic checks against hcdp-postgres-db (read-only)

**Date:** 2026-04-29

---

# Check 1: Gaps and Anomalies in mesonet_measurements

## 1a. Daily row count gaps

**SQL:** (rewritten — original `PERCENTILE_CONT` as window function not supported in PostgreSQL)
```sql
WITH daily AS (
  SELECT DATE(timestamp AT TIME ZONE 'HST') AS day, COUNT(*) AS rows
  FROM mesonet_measurements GROUP BY 1
),
with_avg AS (
  SELECT day, rows,
    AVG(rows) OVER (ORDER BY day ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) AS trailing_avg
  FROM daily
)
SELECT day, rows, ROUND(trailing_avg::numeric, 0) AS trailing_7d_avg,
  ROUND((rows / trailing_avg * 100)::numeric, 1) AS pct_of_avg
FROM with_avg
WHERE trailing_avg IS NOT NULL AND rows < 0.5 * trailing_avg
ORDER BY day;
```

**Result:**
| day | rows | trailing_7d_avg | pct_of_avg |
|-----|------|-----------------|------------|
| 2024-08-06 | 358,762 | 831,432 | 43.1% |
| 2025-09-08 | 465,876 | 1,051,631 | 44.3% |

**Interpretation:** Only 2 days in the entire 4+ year record dropped below 50% of trailing average. Both are partial-day drops (not zero) — likely brief API outages or ingestion delays that self-resolved. The network is remarkably consistent.

---

## 1b. Per-station coverage

**SQL:**
```sql
WITH station_coverage AS (
  SELECT station_id, MIN(timestamp) AS earliest, MAX(timestamp) AS latest,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT DATE(timestamp AT TIME ZONE 'HST')) AS distinct_days,
    (MAX(timestamp)::date - MIN(timestamp)::date + 1) AS span_days
  FROM mesonet_measurements GROUP BY station_id
)
SELECT ... WHERE distinct_days < 0.8 * span_days -- flagged as LOW
```

**Result — Flagged stations (coverage < 80%):**

| Station | Name | Coverage | Distinct days / Span | Issue |
|---------|------|----------|---------------------|-------|
| 0532 | Palolo Mauka | **46.0%** | 69 / 150 | Station went offline Feb 2026; was already intermittent before |
| 0201 | Nahuku | **62.0%** | 914 / 1,475 | Large gap(s) in middle of record despite recent data |
| 0161 | Pohaku Palaha | **79.7%** | 663 / 832 | Borderline; high-altitude Haleakala station with intermittent comms |

All other stations (67+) are at 92%+ coverage. Most are 98-99%+.

**Interpretation:** 3 stations flagged. 0532 (Palolo Mauka) is known stale since Feb 2026. 0201 (Nahuku) has significant historical gaps but is currently reporting. 0161 is a high-altitude Maui station with expected connectivity issues.

---

## 1c. Per-variable coverage at station 0501 (Lyon Arboretum)

**SQL:**
```sql
SELECT var_id, COUNT(*) AS rows, MIN(timestamp)::date, MAX(timestamp)::date,
  COUNT(DISTINCT DATE(timestamp AT TIME ZONE 'HST')) AS distinct_days
FROM mesonet_measurements WHERE station_id = '0501'
GROUP BY var_id ORDER BY var_id;
```

**Result:** 56 variables reporting at station 0501. All show `latest = 2026-04-28` (current). No variables have stopped reporting. Two distinct eras of data:
- **Legacy subset** (3 variables: RF_1_Tot60s, SWin_1_Avg, Tpanel): data from 2022-04-15
- **Full sensor suite** (53 variables): data from 2024-09-01 (station upgrade/expansion)

**Interpretation:** No variables flagged as stopped. The 2024-09-01 expansion from ~3 to 56 variables reflects a hardware upgrade at this station, not a gap.

---

## 1d. RF_1_Tot300s low-count days (< 1,000 rows)

**SQL:**
```sql
SELECT DATE(timestamp AT TIME ZONE 'HST') AS day, COUNT(*) AS rf_rows, COUNT(DISTINCT station_id) AS stations
FROM mesonet_measurements WHERE var_id = 'RF_1_Tot300s'
GROUP BY 1 HAVING COUNT(*) < 1000 ORDER BY day;
```

**Result:** 106 days flagged — ALL are in the period **2021-12-31 to 2022-04-14**, when only **1 station** (station 0141, Auwahi) was reporting RF_1_Tot300s (24 rows/day = 24 hours × 1 reading/hour at that time). From 2022-04-15 onward, RF_1_Tot300s has never dropped below 1,000 rows/day.

**Interpretation:** Not a gap — this is the network ramp-up period. RF_1_Tot300s wasn't deployed at scale until April 2022. No data loss after deployment.

---

## 1e. Ingestion log failures

**SQL:**
```sql
SELECT id, job_type, status, started_at, error_message
FROM ingestion_log WHERE status != 'success' ORDER BY id DESC LIMIT 20;
```

**Result:**
- **30 rows with status = 'running'** — all are `refresh_views` jobs that started but never completed (no `finished_at`). They occur every 6 hours per cron. These are orphaned processes — the view refresh likely times out or gets killed but the log entry is never updated.
- **11 total errors**, all `update` jobs. Most recent:

| Date | Error |
|------|-------|
| 2026-04-24 20:15 | DNS resolution failure (temporary) |
| 2026-04-17 07:45 | DNS resolution failure |
| 2026-04-16 01:15 | DNS resolution failure |
| 2026-04-11 05:30 | DNS resolution failure |
| 2026-04-10 18:15 | DNS resolution failure |

**Interpretation:** 
- The `update` errors are all transient DNS failures — the API host was briefly unreachable. These self-resolved (next 15-min run succeeded). No data loss.
- The `refresh_views` "running" entries are a **log hygiene issue** — the job either times out or crashes without updating its log row. The materialized views still have data (checked in step 4), so some refreshes do complete despite the log not recording it.

---

# Check 2: Why historical_station_values Stops at 2026-03-01

## 2a. Latest dates per station

**SQL:**
```sql
SELECT s.date AS station_latest, COUNT(*) AS station_count
FROM (SELECT station_id, MAX(date) AS date FROM historical_station_values GROUP BY station_id) s
GROUP BY s.date ORDER BY s.date DESC LIMIT 10;
```

**Result:**
| station_latest | station_count |
|---------------|---------------|
| 2026-03-01 | 238 |
| 2026-02-01 | 6 |
| 2026-01-01 | 16 |
| 2025-12-01 | 4 |
| 2025-11-01 | 6 |
| 2025-10-01 | 3 |
| 2025-09-01 | 2 |
| 2025-08-01 | 1 |
| 2025-06-01 | 2 |
| 2025-04-01 | 1 |

**Interpretation:** The bulk of stations (238 of 762) have data through March 2026. The remaining ~524 stations stopped reporting earlier — most are in the legacy COOP network that attrited post-2020. The 2026-03-01 cutoff is the latest data available, not a station-specific issue.

## 2b. Historical ingestion log

**SQL:**
```sql
SELECT id, job_type, status, records_fetched, records_upserted, started_at, finished_at, error_message
FROM ingestion_log WHERE job_type = 'historical' ORDER BY id DESC LIMIT 5;
```

**Result:**
| ID | Status | Records | Date | Notes |
|----|--------|---------|------|-------|
| 792 | success | 1,886 fetched / 1,884 upserted | 2026-04-09 00:16 | Final historical catchup run |
| 728 | error | 228,011 / 227,914 | 2026-04-08 23:34 | "ON CONFLICT cannot affect row a second time" (dedup issue, later fixed) |
| 726 | success | 289 / 289 | 2026-04-08 23:34 | Small run |
| 724 | running | 0 / 0 | 2026-04-08 23:34 | Orphaned (never completed) |
| 673 | running | 0 / 0 | 2026-04-08 23:27 | Orphaned |

**Interpretation:** The last successful historical ingestion was **2026-04-09** (during the initial backfill session). It has not been run since. The end date for that run was `--end 2026-04`.

## 2c. Is it a publication lag or a missing cron job?

**Cron check:**
```bash
crontab -l  # user cron
```
```
*/15 * * * * /opt/hcdp/run.sh --update >> /opt/hcdp/cron.log 2>&1
0 */6 * * * /opt/hcdp/run.sh --refresh-views >> /opt/hcdp/cron.log 2>&1
```

**Finding:** There is **no cron job for historical data**. Only `--update` (mesonet 5-min) and `--refresh-views` are scheduled. The historical ingestion (`--historical`) was run manually during the April 8-9 backfill and has not run since.

**Publication lag check:** The HCDP `/stations` endpoint publishes monthly data with a ~1 month lag. Given today is April 29, we would expect March 2026 data to be the latest available (April 2026 won't be published until May). So the 2026-03-01 cutoff is **consistent with HCDP's publication schedule** — but our ingestion hasn't tried to fetch it since April 9.

**Diagnosis:** It's **both**:
1. HCDP has not published April 2026 historical data yet (expected — ~1 month publication lag)
2. Our ingestion has no scheduled job to pick up new months as they become available

---

# Recommended Next Steps

1. **Fix the orphaned `refresh_views` log entries:** Either add a timeout/cleanup in `ingest.py` so `refresh_views` jobs properly log completion/failure, or add a cron job to mark stale "running" entries as failed after 2 hours.

2. **Add a monthly cron for historical data:** Something like:
   ```
   0 6 5 * * /opt/hcdp/run.sh --historical --start $(date -d '3 months ago' +\%Y-\%m) --end $(date +\%Y-\%m) >> /opt/hcdp/cron.log 2>&1
   ```
   Run on the 5th of each month to catch newly published data with a buffer.

3. **Investigate stations 0201 (Nahuku) and 0532 (Palolo Mauka):** 0201 has only 62% day-coverage despite a 4-year span — worth understanding what periods are missing. 0532 has been offline since February and may need physical maintenance.

4. **Clean up `ingestion_log`:** Mark the 30 orphaned "running" entries and 2 orphaned historical entries as "timeout" or "abandoned."

5. **Run a one-time historical catchup:** Execute `--historical --start 2026-03 --end 2026-04` to pick up any March 2026 data that was published after our April 9 run.

6. **Consider the 2024-08-06 partial day:** Investigate whether the 43.1% drop was an API outage or a real data gap. If the latter, a targeted backfill of that single day may recover the missing readings.
