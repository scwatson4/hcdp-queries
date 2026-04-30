# Data Products

## What's in the database

| Product | Table | Resolution | Period | Rows | Stations |
|---------|-------|-----------|--------|------|----------|
| **Mesonet 5-min** | `mesonet_measurements` | 5-minute | 2022-01-01 → present | 975M+ | 78 active (of 103 registered) |
| **Historical monthly** | `historical_station_values` | Monthly | 1990-01 → 2026-03 | 228k | 564 ever, ~270 currently |
| **Daily summary** | `mv_daily_station_summary` | Daily | 2022 → present | 69k+ | Mirrors mesonet |
| **Monthly summary** | `mv_monthly_station_summary` | Monthly | 2022 → present | 2.4k+ | Mirrors mesonet |

## What's NOT in the database

These exist in the HCDP API but were not ingested:
- **Gridded raster maps** (GeoTIFF): rainfall, temperature, SPI drought index — spatial grids, not point stations
- **Daily-resolution historical station values**: available via API with `period=day`, only `period=month` was ingested
- **Raster time series**: point extractions from gridded maps at arbitrary lat/lng

## Mesonet network growth

| Year | Stations | Rows | Notes |
|------|----------|------|-------|
| 2022 | 19 | 36M | Network launch |
| 2023 | 44 | 135M | Major expansion |
| 2024 | 63 | 280M | Continued growth |
| 2025 | 78 | 390M | Peak station count |
| 2026 | 78 | 120M+ | Ongoing |

## Historical station network attrition

| Period | Stations (statewide) | Notes |
|--------|---------------------|-------|
| 1990-2000 | 320-430 | Growing, peak coverage |
| 2000-2014 | 425-450 | Stable peak |
| 2015-2019 | 420-440 | Slight decline |
| 2020-2021 | 257-269 | **Major drop** (~40% loss) |
| 2022 | 163 | **COOP network collapse** |
| 2023-2026 | 219-228 | Partial recovery |

The COOP (Cooperative Observer) volunteer network collapsed between 2019-2022, going from ~46 to ~1 station on Oahu alone. This is critical for cross-year comparisons — see `methodology.md`.

## Data freshness

The mesonet ingestion cron job runs every 15 minutes. Check freshness:
```sql
SELECT MAX(timestamp) AS latest_data,
       now() - MAX(timestamp) AS data_age
FROM mesonet_measurements;
```

Historical data updates are manual. Last update covered through March 2026.

## Choosing the right table

| Question type | Use this table |
|--------------|---------------|
| Current weather at a station | `v_mesonet_measurements` (latest timestamp) or `mesonet_measurements` with manual filters |
| Daily rainfall/temp for a date range | **`mv_daily_station_summary`** (fast, clean) |
| Monthly/annual aggregation (2022+) | **`mv_monthly_station_summary`** or aggregate from daily QC MV |
| Sub-daily analysis (hourly intensity, flood risk) | `v_mesonet_measurements` with station/var/time filters |
| Historical rainfall before 2022 | `historical_station_values` (monthly only, no QC view — apply manual checks) |
| Hurricane/extreme event pre-2022 | `historical_station_values` (monthly proxy) |
| Station metadata (name, location) | `mesonet_stations` |
| Variable descriptions | `mesonet_variables` |
| Data quality research | `mv_daily_station_summary_unfiltered` / `mesonet_measurements` (unfiltered) |
| Ingestion health | `ingestion_log` |

**Rule of thumb:** Use `mv_daily_station_summary` for any daily-level question — it's 1000x faster than the raw table AND pre-filtered for quality. Only go to `v_mesonet_measurements` or `mesonet_measurements` when you need sub-daily resolution (hourly intensity, 5-minute readings).

**Default vs unfiltered:** Always use the default views (`mv_daily_station_summary`, `mv_monthly_station_summary`, `v_mesonet_measurements`) unless specifically investigating data quality. The `_unfiltered` versions contain sentinel codes (7999, -9999), impossible temperatures (-175°C), and inflated soil moisture that will contaminate any aggregate.
