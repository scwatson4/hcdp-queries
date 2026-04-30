# Database Schema Reference

Database: `hcdp` on PostgreSQL 16 with PostGIS.

## Tables

### mesonet_measurements (PRIMARY — 975M+ rows, 66 GB)

The core table. 5-minute interval readings from the Hawaii Mesonet network.

```
station_id  text                    -- 4-digit mesonet ID (e.g., '0501')
var_id      text                    -- variable name (e.g., 'RF_1_Tot300s')
timestamp   timestamptz             -- UTC timestamp of the reading
value       double precision        -- measured value (units depend on var_id)
flag        text                    -- QC flag (often '0' or NULL — UNRELIABLE, see data_quality.md)
```

**Indexes:**
- `idx_meas_upsert` UNIQUE btree (station_id, var_id, timestamp) — used for upserts
- `idx_meas_station_ts` btree (station_id, timestamp DESC) — station time series
- `idx_meas_var_station_ts` btree (var_id, station_id, timestamp DESC) — variable lookups

**Performance notes:**
- This table is 66 GB with 121 GB of indexes. Full-table scans take 10+ minutes.
- Always filter by station_id AND/OR var_id AND timestamp range. Never `SELECT * FROM mesonet_measurements` without a WHERE clause.
- GROUP BY on the full table (e.g., by year) takes ~10 minutes. Use materialized views when possible.
- Timestamps are stored in UTC. Hawaii Standard Time (HST) is UTC-10 year-round (no daylight saving).

---

### historical_station_values (228k rows, 56 MB)

Monthly rainfall and temperature from the legacy station network (1990–present).

```
station_id  text                    -- SKN station ID (e.g., '140.5') — DIFFERENT from mesonet IDs
date        date                    -- first of the month (e.g., '2022-02-01' for February 2022)
datatype    text                    -- 'rainfall' or 'temperature'
period      text                    -- always 'month'
fill        text                    -- 'partial' (standard)
production  text                    -- 'new' for rainfall, NULL for temperature
aggregation text                    -- NULL for rainfall; 'max', 'min' for temperature
value       double precision        -- monthly total (mm) for rainfall; monthly avg (°C) for temperature
raw_data    jsonb                   -- original API response
```

**Unique constraint:** `(station_id, date, datatype, period, COALESCE(production,''), COALESCE(aggregation,''))`

**CRITICAL: Station IDs are NOT the same as mesonet station IDs.** Historical stations use SKN numbers (e.g., '140.5', '707.4'). To identify which island a historical station is on, you must query the HCDP API metadata — the table itself has no island column. See `stations.md` for details.

**Date format:** Dates like '2022-02' from the API are stored as '2022-02-01'. Always query with first-of-month dates.

---

### mesonet_stations (103 rows)

Station metadata for the mesonet network.

```
station_id   text PRIMARY KEY       -- 4-digit ID (e.g., '0501')
name         text                   -- station name (e.g., 'Lyon Arboretum')
lat          double precision       -- latitude (decimal degrees)
lng          double precision       -- longitude (decimal degrees, negative for Hawaii)
elevation_m  double precision       -- elevation in meters (NULL for some planned stations)
island       text                   -- 'Oahu', 'Maui', 'Hawaii', 'Kauai', 'Molokai', 'Unknown', or NULL
location     text                   -- always 'hawaii'
raw_metadata jsonb                  -- full API response
geom         geometry(Point,4326)   -- PostGIS point (derived from lat/lng)
created_at   timestamptz
updated_at   timestamptz
```

**103 stations registered, ~67 actively reporting.** See `stations.md` for active/stale/never-reported breakdown.

---

### mesonet_variables (279 rows)

Variable metadata.

```
var_id       text PRIMARY KEY       -- variable name (e.g., 'RF_1_Tot300s')
description  text                   -- human-readable description
units        text                   -- measurement units (e.g., 'mm', '°C', 'm/s')
interval_s   integer                -- reporting interval in seconds (NULL for most)
raw_metadata jsonb                  -- full API response
```

See `variables.md` for the key variables you'll use most.

---

### station_monitor (small)

Latest station health snapshot. Not useful for analysis — use mesonet_measurements directly.

```
station_id  text PRIMARY KEY
data        jsonb
fetched_at  timestamptz
```

---

### ingestion_log (operational)

Tracks ingest job history. Useful for debugging data freshness issues.

```
id               serial PRIMARY KEY
job_type         text              -- 'update', 'backfill', 'historical', 'init', 'refresh_views'
started_at       timestamptz
finished_at      timestamptz
records_fetched  integer
records_upserted integer
status           text              -- 'success', 'error', 'running'
error_message    text
details          jsonb
```

The cron job runs `job_type='update'` every 15 minutes. Check recent entries to verify data freshness:
```sql
SELECT id, status, records_upserted, finished_at
FROM ingestion_log ORDER BY id DESC LIMIT 5;
```

---

## Materialized Views

There are two parallel sets of materialized views: `_qc` (filtered) and `_raw` (unfiltered). **Always use the `_qc` versions for downstream analytics.** The `_raw` versions are preserved for data-quality research only.

### v_mesonet_measurements_qc (filter view)

A non-materialized view that excludes:
- NULL values
- Sentinel codes: -9999, -999, 7999, 9999998, 8888, 7777, -8888, -7777
- Per-variable physical range violations (temperature -10 to 50°C, rainfall 0-500mm, humidity 0-105%, etc.)
- Uncalibrated radiation (UC suffix) and enclosure RH are passed through unfiltered

This view is the source for the `mv_*_qc` views.

---

### mv_daily_station_summary_qc (70k+ rows) — **USE THIS ONE**

Pre-aggregated daily statistics per station, QC-filtered. Safe to use without additional filtering.

```
station_id        text
station_name      text
island            text
date_hst          date              -- date in Hawaii Standard Time (UTC-10)
tair_min          double precision  -- daily minimum air temperature (°C)
tair_max          double precision  -- daily maximum air temperature (°C)
tair_avg          double precision  -- daily average air temperature (°C)
rainfall_mm       double precision  -- daily total rainfall (mm)
rh_avg            double precision  -- daily average relative humidity (%)
wind_speed_avg    double precision  -- daily average wind speed (m/s)
wind_speed_max    double precision  -- daily maximum wind speed (m/s)
solar_rad_avg     double precision  -- daily average solar radiation
soil_moisture_avg double precision  -- daily average soil VWC (m³/m³)
```

**Unique index:** idx_mv_daily (station_id, date_hst)

---

### mv_monthly_station_summary_qc (2.4k+ rows) — **USE THIS ONE**

Same columns as daily but aggregated to monthly level. `month` column is first-of-month date. Sourced from the QC daily view.

**Unique index:** idx_mv_monthly (station_id, month)

---

### mv_daily_station_summary_raw / mv_monthly_station_summary_raw

Same structure as the `_qc` versions but include ALL raw values — sentinels, NULLs, range violations. **Do not use for analytics** unless you are specifically researching data quality issues.

**Known contamination in `_raw` views:**
- Station 0122 soil_moisture_avg: ~5,333 (should be ~0.54) due to 7999 sentinels
- Station 0115 rainfall_mm: inflated in March 2023 due to 7999 sentinels
- Station 0153 tair_min: can show -175°C due to sensor faults

---

## Key Relationships

```
mesonet_measurements.station_id  →  mesonet_stations.station_id
mesonet_measurements.var_id      →  mesonet_variables.var_id
mv_daily_station_summary_qc.station_id  →  mesonet_stations.station_id
```

**historical_station_values has NO foreign key to mesonet_stations** — they use different ID systems (SKN vs mesonet 4-digit).
