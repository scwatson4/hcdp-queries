-- Current weather at the closest mesonet station to Manoa (Lyon Arboretum, station 0501)
-- Retrieves the most recent reading for key weather variables
SELECT
  m.station_id,
  s.name,
  m.var_id,
  v.description,
  v.units,
  m.value,
  m.timestamp
FROM mesonet_measurements m
JOIN mesonet_variables v ON v.var_id = m.var_id
JOIN mesonet_stations s ON s.station_id = m.station_id
WHERE m.station_id = '0501'
  AND m.var_id IN ('Tair_1_Avg', 'RH_1_Avg', 'WS_1_Avg', 'WD_1_Avg', 'RF_1_Tot300s', 'SRad_1_Avg', 'SM_1_Avg', 'BP_1_Avg')
  AND m.timestamp = (SELECT MAX(timestamp) FROM mesonet_measurements WHERE station_id = '0501')
ORDER BY m.var_id;

-- Supporting query: 24-hour rainfall total
-- SELECT ROUND(SUM(value)::numeric, 1) AS rain_24h_mm
-- FROM mesonet_measurements
-- WHERE station_id = '0501' AND var_id = 'RF_1_Tot300s'
--   AND timestamp >= now() - interval '24 hours';
-- Result: 0.0 mm
