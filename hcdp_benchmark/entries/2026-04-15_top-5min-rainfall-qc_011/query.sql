-- Primary query: top 20 highest 5-minute rainfall readings
SELECT
    m.station_id,
    s.name,
    s.island,
    m.timestamp,
    m.value,
    ROUND(m.value * 12, 2) AS rate_mm_per_hr,
    m.flag
FROM mesonet_measurements m
JOIN mesonet_stations s ON m.station_id = s.station_id
WHERE m.var_id = 'RF_1_Tot300s'
ORDER BY m.value DESC
LIMIT 20;

-- Supporting query: top 20 excluding sentinel codes (value < 7000)
-- SELECT
--     m.station_id,
--     s.name,
--     s.island,
--     m.timestamp,
--     m.value,
--     ROUND(m.value * 12, 2) AS rate_mm_per_hr,
--     m.flag
-- FROM mesonet_measurements m
-- JOIN mesonet_stations s ON m.station_id = s.station_id
-- WHERE m.var_id = 'RF_1_Tot300s'
--   AND m.value < 7000
-- ORDER BY m.value DESC
-- LIMIT 20;

-- Context query: check surrounding readings for the top non-sentinel reading
-- (station 0602, Common Ground, Kauai — 43.64mm spike)
-- SELECT
--     m.station_id,
--     s.name,
--     m.timestamp,
--     m.value
-- FROM mesonet_measurements m
-- JOIN mesonet_stations s ON m.station_id = s.station_id
-- WHERE m.station_id = '0602'
--   AND m.var_id = 'RF_1_Tot300s'
--   AND m.timestamp BETWEEN '2023-01-01' AND '2023-12-31'
-- ORDER BY m.value DESC
-- LIMIT 30;

-- Context query: check readings immediately before and after a spike
-- SELECT
--     m.timestamp,
--     m.value
-- FROM mesonet_measurements m
-- WHERE m.station_id = '0602'
--   AND m.var_id = 'RF_1_Tot300s'
--   AND m.timestamp BETWEEN (TIMESTAMP '2023-06-15 10:00:00' - INTERVAL '1 hour')
--                        AND (TIMESTAMP '2023-06-15 10:00:00' + INTERVAL '1 hour')
-- ORDER BY m.timestamp;

-- Count of all readings exceeding 10mm in 5 minutes
-- SELECT COUNT(*)
-- FROM mesonet_measurements
-- WHERE var_id = 'RF_1_Tot300s'
--   AND value > 10
--   AND value < 7000;
