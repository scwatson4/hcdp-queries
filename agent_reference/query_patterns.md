# Common Query Patterns

Reusable SQL patterns for frequent question types. **Adapt these to the specific question — don't copy-paste blindly.**

## Current weather at a location

```sql
-- Replace '<sid>' with station_id (see stations.md for location mapping)
SELECT
  m.var_id, v.description, v.units, m.value, m.timestamp
FROM mesonet_measurements m
JOIN mesonet_variables v ON v.var_id = m.var_id
WHERE m.station_id = '<sid>'
  AND m.var_id IN ('Tair_1_Avg', 'RH_1_Avg', 'WS_1_Avg', 'RF_1_Tot300s', 'SM_1_Avg')
  AND m.timestamp = (
    SELECT MAX(timestamp) FROM mesonet_measurements WHERE station_id = '<sid>'
  )
ORDER BY m.var_id;
```

## Rainfall in the last N hours at a station

```sql
SELECT
  ROUND(SUM(value)::numeric, 1) AS rain_mm,
  ROUND((SUM(value) / 25.4)::numeric, 2) AS rain_inches
FROM mesonet_measurements
WHERE station_id = '<sid>'
  AND var_id = 'RF_1_Tot300s'
  AND value IS NOT NULL AND value < 7000
  AND timestamp >= now() - interval '<N> hours';
```

## Daily rainfall for a date range (FAST — use QC MV)

```sql
SELECT date_hst, station_id, station_name, island, rainfall_mm
FROM mv_daily_station_summary_qc
WHERE date_hst BETWEEN '<start>' AND '<end>'
  AND rainfall_mm IS NOT NULL
ORDER BY rainfall_mm DESC;
```
No manual sentinel filters needed — `mv_daily_station_summary_qc` is pre-filtered.

## Heaviest rainfall days across the network

```sql
SELECT d.date_hst, d.station_name, d.island,
  ROUND(d.rainfall_mm::numeric, 1) AS mm,
  ROUND((d.rainfall_mm / 25.4)::numeric, 1) AS inches
FROM mv_daily_station_summary_qc d
WHERE d.date_hst >= '<start>'
  AND d.rainfall_mm IS NOT NULL
ORDER BY d.rainfall_mm DESC
LIMIT 20;
```

## Hourly rainfall intensity (for flood risk assessment)

```sql
SELECT date_trunc('hour', timestamp) AS hour,
  ROUND(SUM(value)::numeric, 1) AS hourly_mm
FROM v_mesonet_measurements_qc
WHERE station_id = '<sid>' AND var_id = 'RF_1_Tot300s'
  AND timestamp >= '<start>' AND timestamp < '<end>'
GROUP BY date_trunc('hour', timestamp)
HAVING SUM(value) > 2
ORDER BY SUM(value) DESC;
```
No manual filters needed — `v_mesonet_measurements_qc` excludes sentinels and range violations.

## Flood risk assessment (soil moisture + rainfall)

```sql
WITH current_sm AS (
  SELECT DISTINCT ON (station_id)
    station_id, value AS current_vwc
  FROM v_mesonet_measurements
  WHERE var_id = 'SM_1_Avg'
  ORDER BY station_id, timestamp DESC
),
recent_rain AS (
  SELECT station_id, SUM(value) AS rain_48h_mm
  FROM v_mesonet_measurements
  WHERE var_id = 'RF_1_Tot300s'
    AND timestamp >= now() - interval '48 hours'
  GROUP BY station_id
)
SELECT c.station_id, s.name, s.island,
  ROUND((c.current_vwc * 100)::numeric, 1) AS vwc_pct,
  ROUND(COALESCE(r.rain_48h_mm, 0)::numeric, 1) AS rain_48h_mm,
  CASE
    WHEN c.current_vwc > 0.55 AND COALESCE(r.rain_48h_mm, 0) > 50 THEN 'HIGH'
    WHEN c.current_vwc > 0.50 THEN 'MODERATE'
    WHEN c.current_vwc > 0.40 THEN 'LOW'
    ELSE 'MINIMAL'
  END AS flood_risk
FROM current_sm c
JOIN mesonet_stations s ON s.station_id = c.station_id
LEFT JOIN recent_rain r ON r.station_id = c.station_id
ORDER BY c.current_vwc DESC;
```

## Station ranking (wettest/driest)

```sql
SELECT s.station_id, s.name, s.island,
  ROUND(s.elevation_m::numeric, 0) AS elev_m,
  COUNT(*) AS days_with_data,
  ROUND(AVG(d.rainfall_mm)::numeric, 2) AS avg_daily_mm,
  ROUND((SUM(d.rainfall_mm) / COUNT(*) * 365)::numeric, 0) AS est_annual_mm
FROM mv_daily_station_summary_qc d
JOIN mesonet_stations s ON s.station_id = d.station_id
WHERE d.rainfall_mm IS NOT NULL
GROUP BY s.station_id, s.name, s.island, s.elevation_m
HAVING COUNT(*) > 365  -- require at least 1 year of data
ORDER BY AVG(d.rainfall_mm) ASC  -- ASC for driest, DESC for wettest
LIMIT 10;
```
No station exclusions needed — `mv_daily_station_summary_qc` already handles sentinel contamination.

## Annual rainfall trend (with reference panel — see methodology.md)

```sql
-- For historical data: requires Oahu SKN list loaded into temp table
-- See methodology.md for the full reference-panel approach
CREATE TEMP TABLE oahu_skns (skn text);
COPY oahu_skns FROM '/tmp/oahu_skns.txt';

WITH panel AS (
  SELECT station_id FROM historical_station_values h
  JOIN oahu_skns o ON o.skn = h.station_id
  WHERE datatype = 'rainfall'
    AND EXTRACT(YEAR FROM date) BETWEEN 2000 AND 2025
  GROUP BY station_id
  HAVING COUNT(DISTINCT EXTRACT(YEAR FROM date)) >= 20
)
SELECT EXTRACT(YEAR FROM h.date)::int AS year,
  COUNT(DISTINCT h.station_id) AS stations,
  ROUND((AVG(h.value) * 12)::numeric, 0) AS est_annual_mm
FROM historical_station_values h
JOIN panel p ON p.station_id = h.station_id
WHERE h.datatype = 'rainfall'
GROUP BY EXTRACT(YEAR FROM h.date)
ORDER BY year;
```

## Historical event lookup (hurricane, drought year)

```sql
-- Monthly rainfall for a specific month/year, ranked by station
SELECT station_id,
  ROUND(value::numeric, 0) AS monthly_mm,
  ROUND((value / 25.4)::numeric, 1) AS monthly_inches
FROM historical_station_values
WHERE date = '<YYYY-MM-01>' AND datatype = 'rainfall'
ORDER BY value DESC
LIMIT 20;

-- Compare to same month in other years (anomaly detection)
SELECT EXTRACT(YEAR FROM date)::int AS year,
  ROUND(MAX(value)::numeric, 0) AS max_station_mm,
  ROUND(AVG(value)::numeric, 0) AS avg_station_mm,
  COUNT(DISTINCT station_id) AS stations
FROM historical_station_values
WHERE datatype = 'rainfall' AND EXTRACT(MONTH FROM date) = <M>
GROUP BY EXTRACT(YEAR FROM date)
ORDER BY AVG(value) ASC;
```

## Station freshness check

```sql
SELECT s.station_id, s.name, s.island,
  MAX(m.timestamp) AS last_reading,
  CASE
    WHEN MAX(m.timestamp) < now() - interval '7 days' THEN 'STALE'
    WHEN MAX(m.timestamp) IS NULL THEN 'NEVER'
    ELSE 'OK'
  END AS status
FROM mesonet_stations s
LEFT JOIN mesonet_measurements m ON m.station_id = s.station_id
GROUP BY s.station_id, s.name, s.island
ORDER BY status DESC, s.island;
```

## Soil moisture time series (for antecedent conditions)

```sql
SELECT date_trunc('day', timestamp)::date AS day,
  ROUND(AVG(value)::numeric, 3) AS avg_vwc,
  ROUND((AVG(value) * 100)::numeric, 1) AS vwc_pct
FROM mesonet_measurements
WHERE station_id = '<sid>' AND var_id = 'SM_1_Avg'
  AND value IS NOT NULL AND value < 1
  AND timestamp BETWEEN '<start>' AND '<end>'
GROUP BY date_trunc('day', timestamp)::date
ORDER BY day;
```

## Performance tips

1. **Use `mv_daily_station_summary_qc` whenever possible** — it's 1000x faster than aggregating `mesonet_measurements`
2. **Always include a timestamp range** — scanning 975M rows without a time filter is a 10+ minute query
3. **Filter by station_id AND var_id** early — the composite indexes work best when both are specified
4. **For "top N" queries**, add `LIMIT` — don't sort the entire table
5. **GROUP BY year on mesonet_measurements** takes ~10 minutes — consider whether the daily/monthly MVs can answer the question instead
