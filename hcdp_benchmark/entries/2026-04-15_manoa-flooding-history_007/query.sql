-- Heavy rainfall days (>50mm) at Manoa-area stations with concurrent soil moisture
WITH manoa_heavy_days AS (
  SELECT d.date_hst, d.station_id, s.name,
    ROUND(d.rainfall_mm::numeric, 1) AS rainfall_mm
  FROM mv_daily_station_summary d
  JOIN mesonet_stations s ON s.station_id = d.station_id
  WHERE d.station_id IN ('0501','0502','0503','0504','0505','0506')
    AND d.rainfall_mm > 50
),
soil AS (
  SELECT date_trunc('day', timestamp)::date AS day,
    ROUND(AVG(value)::numeric, 3) AS avg_vwc
  FROM mesonet_measurements
  WHERE station_id = '0501' AND var_id = 'SM_1_Avg' AND value IS NOT NULL AND value < 1
  GROUP BY date_trunc('day', timestamp)::date
)
SELECT h.date_hst, h.station_id, h.name, h.rainfall_mm,
  s.avg_vwc AS soil_vwc_lyon,
  ROUND((s.avg_vwc * 100)::numeric, 1) AS soil_vwc_pct
FROM manoa_heavy_days h
LEFT JOIN soil s ON s.day = h.date_hst
ORDER BY h.rainfall_mm DESC
LIMIT 30;

-- Supporting queries used in analysis:

-- Multi-day rainfall context at Lyon Arboretum around top events:
-- Mar 10-15 2026: 2.0 + 64.3 + 52.1 + 197.6 + 59.2 + 2.8 = 376mm over 4 days
-- Jan 23-28 2025: 0 + 0 + 0 + 195.3 + 22.4 + 0.3 = 218mm (single-day burst)

-- Soil moisture trajectory at Lyon Arboretum:
-- Pre-March 13: 64% VWC (already saturated from 2 prior rain days)
-- Pre-Jan 26:   46% VWC (drier, soil could absorb rainfall)

-- Peak hourly intensity at Lyon Arboretum:
-- March 13: 16.8 mm/hr sustained over multiple hours
-- Jan 26:   14.7 mm/hr concentrated in one hour
