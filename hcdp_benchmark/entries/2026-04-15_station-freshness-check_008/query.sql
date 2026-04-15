SELECT
  s.station_id,
  s.name,
  s.island,
  ROUND(s.elevation_m::numeric, 0) AS elev_m,
  MAX(m.timestamp) AS last_reading,
  CASE WHEN MAX(m.timestamp) < now() - interval '7 days' THEN 'STALE'
       WHEN MAX(m.timestamp) IS NULL THEN 'NEVER'
       ELSE 'OK' END AS status
FROM mesonet_stations s
LEFT JOIN mesonet_measurements m ON m.station_id = s.station_id
GROUP BY s.station_id, s.name, s.island, s.elevation_m
ORDER BY status DESC, s.island, s.station_id;
