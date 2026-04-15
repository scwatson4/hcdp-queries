-- Per-island average daily rainfall and station count for March 2026
-- Used to estimate total volume of rain across all Hawaiian islands
SELECT
  s.island,
  COUNT(DISTINCT d.station_id) AS stations,
  ROUND(AVG(d.rainfall_mm)::numeric, 2) AS avg_daily_mm,
  ROUND(SUM(d.rainfall_mm)::numeric / COUNT(DISTINCT d.station_id), 2) AS monthly_total_per_station_mm
FROM mv_daily_station_summary d
JOIN mesonet_stations s ON s.station_id = d.station_id
WHERE d.date_hst >= '2026-03-01' AND d.date_hst < '2026-04-01'
  AND d.rainfall_mm IS NOT NULL
GROUP BY s.island
ORDER BY stations DESC;

-- Also used the historical station network for a better statewide average:
-- SELECT datatype, COUNT(*), ROUND(AVG(value)::numeric, 2) AS avg_value
-- FROM historical_station_values
-- WHERE date = '2026-03-01' AND datatype = 'rainfall'
-- GROUP BY datatype;
-- Result: 133 stations, avg 529.03 mm

-- Volume calculation:
-- Total island land area: 16,627 km²
-- Average rainfall (133 historical stations): 529.03 mm
-- Volume = 16,627 km² × 0.52903 m = 8,796,181,810 m³
-- = 8,796,181,810,000 liters
-- = 2,323,704,941,111 gallons
-- ≈ 2.3 trillion gallons
