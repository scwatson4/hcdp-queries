# Query: Diagnose why a chatbot query against mv_monthly_station_summary_qc returned ZERO rows

**Date:** 2026-06-10 11:45 UTC
**Mode:** read-only diagnostic, no changes made.

A chatbot session ran this query and got zero rows with no error:

```sql
SELECT month, COUNT(*) FILTER (WHERE rainfall_mm IS NOT NULL) AS stations,
       ROUND(AVG(rainfall_mm)::numeric, 1) AS avg_station_rainfall_mm
FROM mv_monthly_station_summary_qc
WHERE island = 'Hawaii'
  AND month >= DATE '2026-01-01' AND month < DATE '2026-05-01'
  AND rainfall_mm IS NOT NULL
GROUP BY month ORDER BY month;
```

---

## Verdict

**The query as pasted works.** Running it verbatim returns 4 rows:

| month | stations | avg_station_rainfall_mm |
|-------|----------|-------------------------|
| 2026-01-01 | 27 | 129.4 |
| 2026-02-01 | 27 | 348.1 |
| 2026-03-01 | 27 | 471.3 |
| 2026-04-01 | 27 | 136.3 |

The matview exists, has data through 2026-06-01, and is fresh. **What actually went wrong in the chatbot session is almost certainly an `island` value mismatch.** The bot used (or rewrote the WHERE clause to) `island = 'Hawaiʻi'` with the ʻokina — confirmed below — which returns **zero rows silently**.

```sql
-- Same query with the ʻokina form:
SELECT … WHERE island = 'Hawaiʻi' AND month >= …
-- returns: (0 rows)
```

## Why the agent made this mistake

The agent reference docs (`stations.md`, `geography.md`) and the `hawaii_islands` PostGIS table all use **ʻokina forms** throughout — `Hawaiʻi`, `Oʻahu`, `Kauaʻi`, `Molokaʻi`, etc. — because that's the linguistically correct rendering and matches the PostGIS island-masking table. An agent reading those docs would reasonably assume `Hawaiʻi` is the canonical value, then apply it to the matviews. Silent failure.

## Island-vocabulary divergence across the database

| Object | Island column | Vocabulary |
|---|---|---|
| `mesonet_stations.island` | yes | **plain ASCII** — `Hawaii`, `Kauai`, `Maui`, `Molokai`, `Oahu`, `Unknown`, plus a few NULL/empty rows |
| `mv_daily_station_summary_qc.island` | yes | **plain ASCII** — same |
| `mv_daily_station_summary_raw.island` | yes | **plain ASCII** — inherited from mesonet_stations |
| `mv_monthly_station_summary_qc.island` | yes | **plain ASCII** — same |
| `mv_monthly_station_summary_raw.island` | yes | **plain ASCII** — same |
| `hawaii_islands.island_name` (PostGIS table for raster masking) | column is `island_name`, **not** `island` | **ʻokina** — `Hawaiʻi`, `Kahoʻolawe`, `Kauaʻi`, `Lānaʻi`, `Maui`, `Molokaʻi`, `Niʻihau`, `Oʻahu` |

Note the second-order trap: `hawaii_islands` is the only object with the ʻokina spellings, and its column is `island_name` (not `island`), so an information-schema search for "columns named `island`" misses it entirely.

## Raw diagnostic output

### 1. Existing monthly + station views

```
                           List of relations
 Schema |              Name              |       Type        |  Owner
--------+--------------------------------+-------------------+----------
 public | mv_monthly_station_summary_qc  | materialized view | postgres
 public | mv_monthly_station_summary_raw | materialized view | postgres
 public | mv_daily_station_summary_qc    | materialized view | postgres
 public | mv_daily_station_summary_raw   | materialized view | postgres
```

### 2a. Columns of `mv_monthly_station_summary_qc`

```
       Materialized view "public.mv_monthly_station_summary_qc"
      Column       |       Type
-------------------+------------------
 station_id        | text
 station_name      | text
 island            | text
 month             | date
 tair_min          | double precision
 tair_max          | double precision
 tair_avg          | double precision
 rainfall_mm       | double precision
 rh_avg            | double precision
 wind_speed_avg    | double precision
 wind_speed_max    | double precision
 solar_rad_avg     | double precision
 soil_moisture_avg | double precision
Indexes:
    "idx_mv_monthly_qc" UNIQUE, btree (station_id, month)
```

### 2b. Island vocabulary — the smoking gun

```
SELECT DISTINCT island FROM mv_monthly_station_summary_qc ORDER BY 1;

 island
---------
 Hawaii
 Kauai
 Maui
 Molokai
 Oahu
 Unknown
        ← NULL/empty row
(7 rows)
```

### 2c. Freshness

```
 mv_monthly_station_summary_qc:  MIN=2021-12-01  MAX=2026-06-01  rows=2,535
 mv_daily_station_summary_qc:    MIN=2021-12-31  MAX=2026-06-09  rows=73,484
```

### 3. mv_daily_station_summary_qc has the same plain-ASCII vocabulary

```
SELECT DISTINCT island FROM mv_daily_station_summary_qc ORDER BY 1;
→ Hawaii, Kauai, Maui, Molokai, Oahu, Unknown, NULL
```

### Confirming the cause

```sql
-- The user's exact query, run verbatim:
SELECT month, COUNT(*) FILTER (...), ROUND(AVG(...)::numeric, 1) ...
FROM mv_monthly_station_summary_qc
WHERE island = 'Hawaii' AND month >= '2026-01-01' AND month < '2026-05-01'
  AND rainfall_mm IS NOT NULL
GROUP BY month ORDER BY month;
→ 4 rows (shown above)

-- Same query with ʻokina form:
… WHERE island = 'Hawaiʻi' …
→ 0 rows ← SILENT FAILURE
```

## Smallest fix (not applied — your decision)

**Option A — corrected query template:** keep the user's pattern, just clarify `island = 'Hawaii'` (plain ASCII) is required for station matviews. Useful but only fixes this one query.

**Option B — note for `agent_reference/schema.md`** (recommended, durable):

> ### Island vocabulary
>
> Two different naming conventions live in this database, and they don't cross-match:
>
> - **Station tables/views** (`mesonet_stations`, `mv_daily_station_summary_qc`, `mv_monthly_station_summary_qc`, and their `_raw` siblings) — use **plain ASCII**: `Hawaii`, `Kauai`, `Maui`, `Molokai`, `Oahu`, `Unknown` (plus a few NULL/empty rows). Filter with `island = 'Hawaii'`.
>
> - **PostGIS table `hawaii_islands`** (used for raster masking) — column is `island_name`, not `island`, and uses **ʻokina forms**: `Hawaiʻi`, `Kahoʻolawe`, `Kauaʻi`, `Lānaʻi`, `Maui`, `Molokaʻi`, `Niʻihau`, `Oʻahu`. Filter with `island_name = 'Hawaiʻi'`.
>
> Mixing these — e.g., `WHERE island = 'Hawaiʻi'` against a station view — silently returns zero rows.

Option B fixes the cause; Option A only fixes the symptom for one query. I'd recommend B unless you also want a corrected query template added to `query_patterns.md`.
