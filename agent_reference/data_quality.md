# Data Quality Rules

**Read this before running any query.** These rules prevent you from reporting sensor errors as weather records.

## Rule 1: Filter the 7999 sentinel code

The value `7999` is a **sensor error/overflow code**, not a measurement. It appears in:
- `RF_1_Tot300s` (rainfall) at station 0115 — 250 consecutive readings of exactly 7999 in March 2023
- `SM_1_Avg` (soil moisture) at station 0122 — persistent 7999 readings

**Always add this filter to rainfall queries:**
```sql
WHERE var_id = 'RF_1_Tot300s' AND value IS NOT NULL AND value < 7000
```

**Always add this filter to soil moisture queries:**
```sql
WHERE var_id = 'SM_1_Avg' AND value IS NOT NULL AND value < 1
```

If you forget this filter:
- Station 0115 will appear as having 1,999,750 mm of rainfall in March 2023 (~79,000 inches)
- Station 0122 will appear as having 799,900% soil moisture
- Any aggregate (avg, sum, max) touching these stations will be wildly wrong
- **The `mv_daily_station_summary` materialized view DOES include these bad values** in its `rainfall_mm` column

## Rule 2: Station 0602 has chronic rainfall spikes

Station 0602 (Common Ground, Kauai) has a **tipping bucket malfunction** that produces isolated extreme readings:
- Single 5-minute readings of 30-44mm surrounded by zeros
- Pattern: `0→0→0→SPIKE→0→0→0` (classic stuck-bucket dump)
- 5 occurrences identified between 2023-2025
- Readings >30mm/5min (~360 mm/hr) are almost certainly artifacts here

These values don't trigger the 7999 filter. For extreme-value analyses, check surrounding context:
```sql
-- Check if a high reading is isolated (suspicious) or part of a storm (real)
SELECT timestamp, value FROM mesonet_measurements
WHERE station_id = '<sid>' AND var_id = 'RF_1_Tot300s'
  AND timestamp BETWEEN '<timestamp>'::timestamptz - interval '30 minutes'
                  AND '<timestamp>'::timestamptz + interval '30 minutes'
ORDER BY timestamp;
```

## Rule 3: Physical plausibility thresholds

| Variable | Suspicious above | Impossible above | Notes |
|----------|-----------------|-----------------|-------|
| RF_1_Tot300s (mm/5min) | 15 mm | 50 mm | World record ~12.7mm/5min |
| RF_1_Tot300s rate (mm/hr) | 180 mm/hr | 600 mm/hr | |
| Tair_1_Avg (°C) | 38 | 45 | Hawaii record high ~38°C |
| SM_1_Avg (m³/m³) | 0.75 | 1.0 | Saturated soil ~0.4-0.7 depending on type |
| WS_1_Avg (m/s) | 30 | 50 | Hurricane-force winds |

## Rule 4: The flag field is unreliable

The `flag` column in `mesonet_measurements` is almost always `0` or `NULL`, even for obviously bad data. **Do not trust `flag=0` to mean "good data."** The HCDP automated QC system does not catch sentinel codes or mechanical artifacts. Apply your own filters per the rules above.

## Rule 5: Check station freshness

Before reporting "current weather" from a station, verify it's actually current:
```sql
SELECT MAX(timestamp) FROM mesonet_measurements WHERE station_id = '<sid>';
```

Some stations go offline for days/weeks without warning. If the latest reading is >1 hour old, note this in your answer. If >7 days old, the station is stale — report it and use a different station.

## Known bad data inventory

| Station | Variable | Period | Issue | Impact |
|---------|----------|--------|-------|--------|
| 0115 | RF_1_Tot300s | March 5-6, 2023 | 250 readings of 7999 | Inflates any March 2023 rainfall stat; makes 0115 appear as wettest station if unfiltered |
| 0602 | RF_1_Tot300s | 2023-2025 (recurring) | Isolated 30-44mm spikes | Appears in top-N rainfall rankings |
| 0122 | SM_1_Avg | Ongoing | Persistent 7999 | Breaks any soil moisture ranking or average |
| 0245 | All | Since Jan 2026 | Station offline | Missing data, not bad data |
| 0532 | All | Since Feb 2026 | Station offline | Missing data, not bad data |

## Recommended approach: use _qc materialized views

As of 2026-04-29, QC-filtered materialized views exist:
- **`mv_daily_station_summary_qc`** — use instead of `mv_daily_station_summary_raw`
- **`mv_monthly_station_summary_qc`** — use instead of `mv_monthly_station_summary_raw`
- **`v_mesonet_measurements_qc`** — use instead of `mesonet_measurements` for raw 5-min data

These exclude NULLs, sentinel codes, and physical range violations automatically. **Use _qc views by default.** Manual filters below are only needed if querying raw tables directly.

The pressure variables (P_1_Avg, Psl_1_Avg) are in **kPa** not hPa. The QC view uses range 60-105 kPa.

Uncalibrated radiation variables (suffix UC) are passed through unfiltered — treat with caution.

Station-level QC (e.g., station 0122 soil moisture is unreliable even after filtering) is NOT applied in the _qc views — that requires a future station_quality reference table.

## Manual filters (for raw table queries)

If you must query `mesonet_measurements` directly:
```sql
-- For rainfall
WHERE var_id = 'RF_1_Tot300s'
  AND value IS NOT NULL
  AND value < 7000              -- exclude sentinel codes
  AND station_id != '0602'      -- exclude if doing extreme-value analysis

-- For soil moisture
WHERE var_id = 'SM_1_Avg'
  AND value IS NOT NULL
  AND value < 1                 -- exclude sentinel codes (7999)

-- For the raw daily materialized view
WHERE rainfall_mm IS NOT NULL
  AND station_id != '0115'      -- exclude sensor-error-inflated station
```
