-- Top 20 extreme rainfall days across all stations in last 6 months
SELECT
  d.date_hst,
  s.name,
  s.island,
  ROUND(d.rainfall_mm::numeric, 1) AS rainfall_mm,
  ROUND((d.rainfall_mm / 25.4)::numeric, 1) AS rainfall_inches
FROM mv_daily_station_summary d
JOIN mesonet_stations s ON s.station_id = d.station_id
WHERE d.date_hst >= '2025-10-01'
  AND d.rainfall_mm IS NOT NULL
ORDER BY d.rainfall_mm DESC
LIMIT 20;

-- Supporting query: daily totals around the event
-- SELECT date_hst, COUNT(DISTINCT station_id), AVG(rainfall_mm), MAX(rainfall_mm), SUM(rainfall_mm)
-- FROM mv_daily_station_summary
-- WHERE date_hst BETWEEN '2026-03-10' AND '2026-03-18' AND rainfall_mm IS NOT NULL
-- GROUP BY date_hst ORDER BY date_hst;
-- Result: March 14 averaged 174.6 mm/station (30x normal), 46 of 74 stations over 100mm
