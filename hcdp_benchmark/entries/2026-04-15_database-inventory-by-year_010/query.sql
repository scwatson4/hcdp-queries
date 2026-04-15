-- Database inventory: rows, distinct stations, and date range by product and year
WITH mesonet AS (
  SELECT 'mesonet_5min'::text AS product, EXTRACT(YEAR FROM timestamp)::int AS year,
    COUNT(*) AS rows, COUNT(DISTINCT station_id) AS distinct_stations,
    MIN(timestamp)::text AS earliest, MAX(timestamp)::text AS latest
  FROM mesonet_measurements GROUP BY EXTRACT(YEAR FROM timestamp)
),
historical AS (
  SELECT 'historical_monthly'::text, EXTRACT(YEAR FROM date)::int,
    COUNT(*), COUNT(DISTINCT station_id),
    MIN(date)::text, MAX(date)::text
  FROM historical_station_values GROUP BY EXTRACT(YEAR FROM date)
),
daily_mv AS (
  SELECT 'mv_daily_summary'::text, EXTRACT(YEAR FROM date_hst)::int,
    COUNT(*), COUNT(DISTINCT station_id),
    MIN(date_hst)::text, MAX(date_hst)::text
  FROM mv_daily_station_summary GROUP BY EXTRACT(YEAR FROM date_hst)
),
monthly_mv AS (
  SELECT 'mv_monthly_summary'::text, EXTRACT(YEAR FROM month)::int,
    COUNT(*), COUNT(DISTINCT station_id),
    MIN(month)::text, MAX(month)::text
  FROM mv_monthly_station_summary GROUP BY EXTRACT(YEAR FROM month)
)
SELECT * FROM historical
UNION ALL SELECT * FROM mesonet
UNION ALL SELECT * FROM daily_mv
UNION ALL SELECT * FROM monthly_mv
ORDER BY 1, 2;

-- Note: gridded/raster products are available via the HCDP /raster API endpoint
-- but were not ingested into this database (they are GeoTIFF files, not tabular data).
-- Daily-resolution historical station values also exist in the API (period=day)
-- but only monthly (period=month) was ingested.
