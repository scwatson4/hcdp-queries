-- Driest stations by average daily rainfall (mm/day) over full history
-- Requires at least 1 year of data to filter out stations with sparse records
SELECT
  s.station_id,
  s.name,
  s.island,
  ROUND(s.elevation_m::numeric, 0) AS elev_m,
  COUNT(*) AS days_with_data,
  ROUND(SUM(d.rainfall_mm)::numeric, 1) AS total_mm,
  ROUND(AVG(d.rainfall_mm)::numeric, 2) AS avg_daily_mm,
  ROUND((SUM(d.rainfall_mm) / COUNT(*) * 365)::numeric, 0) AS est_annual_mm
FROM mv_daily_station_summary d
JOIN mesonet_stations s ON s.station_id = d.station_id
WHERE d.rainfall_mm IS NOT NULL
GROUP BY s.station_id, s.name, s.island, s.elevation_m
HAVING COUNT(*) > 365
ORDER BY AVG(d.rainfall_mm) ASC
LIMIT 10;
