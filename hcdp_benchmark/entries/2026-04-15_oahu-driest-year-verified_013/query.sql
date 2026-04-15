-- ============================================================================
-- NAIVE VERSION (do not use): produces biased result, see narrative.md
-- Uses all reporting stations per year, but station count dropped from ~125
-- (2019) to 54 (2022) due to COOP network attrition, making cross-year
-- comparisons unreliable.
-- ============================================================================
--
-- CREATE TEMP TABLE oahu_skns (skn text);
-- COPY oahu_skns FROM '/tmp/oahu_skns.txt';  -- 760 Oahu SKNs from API metadata
--
-- SELECT
--   EXTRACT(YEAR FROM h.date)::int AS year,
--   COUNT(DISTINCT h.station_id) AS stations,
--   ROUND(AVG(h.value)::numeric, 1) AS avg_monthly_mm,
--   ROUND((AVG(h.value) * 12)::numeric, 0) AS est_annual_mm,
--   ROUND((AVG(h.value) * 12 / 25.4)::numeric, 1) AS est_annual_in
-- FROM historical_station_values h
-- JOIN oahu_skns o ON o.skn = h.station_id
-- WHERE h.datatype = 'rainfall'
-- GROUP BY EXTRACT(YEAR FROM h.date)
-- HAVING COUNT(DISTINCT h.station_id) >= 10
-- ORDER BY AVG(h.value) ASC;
--
-- Result: 2022 = 935mm (36.8 in), 54 stations. Suspicious because of
-- station count drop — could be composition artifact.

-- ============================================================================
-- GOLD VERSION: Stable reference panel, verified against composition artifact
-- ============================================================================
-- Step 1: Identify Oahu stations from API metadata (island='OA')
-- Step 2: Build reference panel = stations with >=20 of 26 years reporting
--         (2000-2025) that ALSO reported in 2022
-- Step 3: Compute annual rainfall using ONLY these 41 stations across all years

CREATE TEMP TABLE oahu_skns (skn text);
COPY oahu_skns FROM '/tmp/oahu_skns.txt';

WITH panel_with_2022 AS (
  -- 41 stations: long-running AND reported in 2022
  SELECT DISTINCT p.station_id
  FROM (
    SELECT h.station_id
    FROM historical_station_values h
    JOIN oahu_skns o ON o.skn = h.station_id
    WHERE h.datatype = 'rainfall'
      AND EXTRACT(YEAR FROM h.date) BETWEEN 2000 AND 2025
    GROUP BY h.station_id
    HAVING COUNT(DISTINCT EXTRACT(YEAR FROM h.date)) >= 20
  ) p
  JOIN historical_station_values h ON h.station_id = p.station_id
  WHERE h.datatype = 'rainfall' AND EXTRACT(YEAR FROM h.date) = 2022
),
yearly AS (
  SELECT
    EXTRACT(YEAR FROM h.date)::int AS year,
    COUNT(DISTINCT h.station_id) AS stations_reporting,
    ROUND(AVG(h.value)::numeric, 1) AS avg_monthly_mm,
    ROUND((AVG(h.value) * 12)::numeric, 0) AS est_annual_mm,
    ROUND((AVG(h.value) * 12 / 25.4)::numeric, 1) AS est_annual_in
  FROM historical_station_values h
  JOIN panel_with_2022 p ON p.station_id = h.station_id
  WHERE h.datatype = 'rainfall'
    AND EXTRACT(YEAR FROM h.date) BETWEEN 2000 AND 2025
  GROUP BY EXTRACT(YEAR FROM h.date)
)
SELECT year, stations_reporting, avg_monthly_mm, est_annual_mm, est_annual_in,
  RANK() OVER (ORDER BY est_annual_mm ASC) AS dry_rank
FROM yearly
ORDER BY est_annual_mm ASC;

-- Supporting: network composition of the 41-station panel
-- HydroNet-UaNet: 20, RAWS: 11, USGS: 8, NWS: 2
-- Zero COOP stations (all 42 COOP panel stations dropped out of 2022)

-- Supporting: long-term mean of the panel
-- 1,458 mm (57.4 in) across 2000-2025
-- 2022 = 985 mm = 67.5% of mean
-- 2000 (#2 driest) = 1,127 mm = 77.3% of mean
-- Gap between #1 and #2: 10 percentage points
