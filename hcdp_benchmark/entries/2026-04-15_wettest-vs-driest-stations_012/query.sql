-- Top 5 wettest and top 5 driest stations across all Hawaiian islands.
--
-- Station 0115 (Piʻiholo, Maui) is excluded because its rainfall sensor
-- periodically reports 7999mm error values, which inflate its apparent
-- annual rainfall from ~800mm to ~616,588mm. The error contribution
-- (1,999,750mm total) dwarfs its real rainfall (5,427mm).

WITH station_rain AS (
  SELECT
    d.station_id,
    s.name,
    s.island,
    s.elevation_m                                    AS elev_m,
    COUNT(*)                                         AS days_with_data,
    ROUND(AVG(d.rainfall_mm)::numeric, 2)            AS avg_daily_mm,
    ROUND((AVG(d.rainfall_mm) * 365)::numeric, 0)    AS est_annual_mm,
    ROUND((AVG(d.rainfall_mm) * 365 / 25.4)::numeric, 0) AS est_annual_in,
    ROUND(MAX(d.rainfall_mm)::numeric, 1)            AS max_single_day_mm,
    ROUND(100.0 * COUNT(*) FILTER (WHERE d.rainfall_mm > 0.2)
          / COUNT(*)::numeric, 1)                    AS pct_rainy_days
  FROM mv_daily_station_summary d
  JOIN stations s ON s.station_id = d.station_id
  WHERE d.rainfall_mm IS NOT NULL
    AND d.station_id != '0115'          -- exclude: sensor error (see comment above)
  GROUP BY d.station_id, s.name, s.island, s.elevation_m
  HAVING COUNT(*) >= 365                -- require at least ~1 year of data
),
wet AS (
  SELECT 'WET #' || ROW_NUMBER() OVER (ORDER BY avg_daily_mm DESC) AS rank,
         station_id, name, island, elev_m, days_with_data,
         avg_daily_mm, est_annual_mm, est_annual_in,
         max_single_day_mm, pct_rainy_days
  FROM station_rain
  ORDER BY avg_daily_mm DESC
  LIMIT 5
),
dry AS (
  SELECT 'DRY #' || ROW_NUMBER() OVER (ORDER BY avg_daily_mm ASC) AS rank,
         station_id, name, island, elev_m, days_with_data,
         avg_daily_mm, est_annual_mm, est_annual_in,
         max_single_day_mm, pct_rainy_days
  FROM station_rain
  ORDER BY avg_daily_mm ASC
  LIMIT 5
)
SELECT * FROM wet
UNION ALL
SELECT * FROM (SELECT * FROM dry ORDER BY avg_daily_mm ASC) sub
ORDER BY
  CASE WHEN rank LIKE 'WET%' THEN 0 ELSE 1 END,
  CASE WHEN rank LIKE 'WET%' THEN avg_daily_mm END DESC NULLS LAST,
  CASE WHEN rank LIKE 'DRY%' THEN avg_daily_mm END ASC NULLS LAST;
