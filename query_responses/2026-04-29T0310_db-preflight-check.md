# Query: Check whether the hcdp-postgres-db contains both mesonet data and HCDP historical station data

**Date:** 2026-04-29

---

## Checks performed

### 1. All tables in public schema

| Table | Type | Size | Approx Rows |
|-------|------|------|-------------|
| `mesonet_measurements` | table | 189 GB | 934M (est) |
| `historical_station_values` | table | 75 MB | 228,414 |
| `mesonet_stations` | table | 152 kB | 103 |
| `mesonet_variables` | table | 216 kB | 279 |
| `station_monitor` | table | 224 kB | 77 |
| `ingestion_log` | table | 456 kB | 3,372 |
| `spatial_ref_sys` | table | 7,144 kB | 8,500 |
| `mv_daily_station_summary` | matview | 22 MB | 69,923 |
| `mv_monthly_station_summary` | matview | 824 kB | 2,383 |

### 2. Mesonet data

```
station_count:      103
variable_count:     279
measurement_count:  975,576,345
earliest_hst:       2021-12-31 14:00:00
latest_hst:         2026-04-28 17:35:00
```

Sample station IDs: `0115`, `0116`, `0118`, `0119`, `0121` — confirmed zero-padded text format.

### 3. Historical station data

```
row_count:          228,414
earliest:           1990-01-01
latest:             2026-03-01
distinct_stations:  762
```

Sample station IDs: `1146.0`, `1117.9`, `1075.0`, `1074.0`, `1069.0` — confirmed SKN decimal format, distinct from mesonet IDs.

### 4. Materialized views

| View | Rows |
|------|------|
| `mv_daily_station_summary` | 69,923 |
| `mv_monthly_station_summary` | 2,383 |

## Summary

| Dataset | Table | Rows | Date Range (HST) | Sample IDs | Status |
|---------|-------|------|------------------|------------|--------|
| **Mesonet stations** | `mesonet_stations` | 103 | — | `0115`, `0116`, `0118`... (zero-padded text) | OK |
| **Mesonet variables** | `mesonet_variables` | 279 | — | — | OK |
| **Mesonet measurements** | `mesonet_measurements` | **975.6M** | 2021-12-31 → 2026-04-28 17:35 | — | OK |
| **Historical station values** | `historical_station_values` | 228,414 | 1990-01-01 → 2026-03-01 | `1146.0`, `1117.9`, `1075.0`... (SKN decimal format) | OK |
| **Daily summary (MV)** | `mv_daily_station_summary` | 69,923 | — | — | OK |
| **Monthly summary (MV)** | `mv_monthly_station_summary` | 2,383 | — | — | OK |
| **Station monitor** | `station_monitor` | 77 | — | — | OK |
| **Ingestion log** | `ingestion_log` | 3,372 | — | — | OK |

**Everything checks out.** Both mesonet (975.6M rows, 2022-present) and historical (228k rows, 1990-present) data are loaded. Station ID formats are confirmed distinct (mesonet: `0501` zero-padded, historical: `1094.2` SKN decimal). Both materialized views have data. Total DB size: ~189 GB. Nothing missing or suspiciously empty.
