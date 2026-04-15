-- Flood risk assessment combining current soil moisture, 7-day trend, and recent rainfall
-- SM_1_Avg = soil volumetric water content (m³/m³), values 0-1 (100% = fully saturated)
-- Excludes value >= 1 which indicates sensor error (e.g., 7999 from broken probes)
WITH current_sm AS (
  SELECT DISTINCT ON (station_id)
    station_id, value AS current_vwc, timestamp
  FROM mesonet_measurements
  WHERE var_id = 'SM_1_Avg' AND value IS NOT NULL AND value < 1
  ORDER BY station_id, timestamp DESC
),
week_ago_sm AS (
  SELECT DISTINCT ON (station_id)
    station_id, value AS prev_vwc
  FROM mesonet_measurements
  WHERE var_id = 'SM_1_Avg' AND value IS NOT NULL AND value < 1
    AND timestamp BETWEEN '2026-04-08 00:00:00+00' AND '2026-04-08 23:59:59+00'
  ORDER BY station_id, timestamp DESC
),
recent_rain AS (
  SELECT station_id, SUM(value) AS rain_48h_mm
  FROM mesonet_measurements
  WHERE var_id = 'RF_1_Tot300s' AND value IS NOT NULL AND value < 7000
    AND timestamp >= now() - interval '48 hours'
  GROUP BY station_id
)
SELECT
  c.station_id,
  s.name,
  s.island,
  ROUND(s.elevation_m::numeric, 0) AS elev_m,
  ROUND((c.current_vwc * 100)::numeric, 1) AS current_vwc_pct,
  ROUND(((c.current_vwc - w.prev_vwc) * 100)::numeric, 1) AS vwc_change_7d_pct,
  ROUND(COALESCE(r.rain_48h_mm, 0)::numeric, 1) AS rain_48h_mm,
  CASE
    WHEN c.current_vwc > 0.55 AND COALESCE(r.rain_48h_mm, 0) > 50 THEN 'HIGH'
    WHEN c.current_vwc > 0.50 OR (c.current_vwc > 0.40 AND COALESCE(r.rain_48h_mm, 0) > 100) THEN 'MODERATE'
    WHEN c.current_vwc > 0.40 THEN 'LOW'
    ELSE 'MINIMAL'
  END AS flood_risk
FROM current_sm c
JOIN mesonet_stations s ON s.station_id = c.station_id
LEFT JOIN week_ago_sm w ON w.station_id = c.station_id
LEFT JOIN recent_rain r ON r.station_id = c.station_id
ORDER BY c.current_vwc DESC
LIMIT 25;
