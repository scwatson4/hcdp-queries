-- Hurricane Lane hit Hawaii August 22-26, 2018.
-- Mesonet data starts 2022, so we must use historical_station_values (monthly resolution).

-- Top stations by August 2018 monthly rainfall
SELECT
  h.station_id AS skn,
  ROUND(h.value::numeric, 0) AS aug_2018_mm,
  ROUND((h.value / 25.4)::numeric, 1) AS aug_2018_inches
FROM historical_station_values h
WHERE h.date = '2018-08-01' AND h.datatype = 'rainfall'
ORDER BY h.value DESC
LIMIT 20;

-- Supporting query: Lane excess above normal August
-- SELECT
--   h.station_id AS skn,
--   ROUND(AVG(CASE WHEN EXTRACT(YEAR FROM date) != 2018 THEN h.value END)::numeric, 0) AS avg_aug_mm_excl_2018,
--   ROUND(MAX(CASE WHEN EXTRACT(YEAR FROM date) = 2018 THEN h.value END)::numeric, 0) AS aug_2018_mm,
--   ROUND((MAX(CASE WHEN EXTRACT(YEAR FROM date) = 2018 THEN h.value END)
--     - AVG(CASE WHEN EXTRACT(YEAR FROM date) != 2018 THEN h.value END))::numeric, 0) AS lane_excess_mm
-- FROM historical_station_values h
-- WHERE h.datatype = 'rainfall' AND EXTRACT(MONTH FROM date) = 8
-- GROUP BY h.station_id
-- HAVING MAX(CASE WHEN EXTRACT(YEAR FROM date) = 2018 THEN h.value END) > 1500
-- ORDER BY lane_excess_mm DESC;
-- Result: Station 277 had highest excess of 1,700mm; station 140.5 had 1,691mm

-- Supporting query: August comparison across years (to confirm 2018 is an outlier)
-- SELECT EXTRACT(YEAR FROM date), MAX(value), AVG(value), COUNT(*)
-- FROM historical_station_values
-- WHERE datatype='rainfall' AND EXTRACT(MONTH FROM date)=8 AND date >= '2015-01-01'
-- GROUP BY EXTRACT(YEAR FROM date) ORDER BY year;
-- Result: Aug 2018 max=2166mm, avg=478mm; next highest Aug max=1403mm (2016)
