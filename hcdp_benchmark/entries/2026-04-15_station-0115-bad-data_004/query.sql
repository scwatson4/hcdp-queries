-- Raw 5-minute rainfall readings for station 0115 (Piiholo, Maui) around the bad dates
-- RF_1_Tot300s = rainfall accumulated over 300-second (5-minute) intervals, in mm
SELECT
  m.station_id,
  s.name,
  m.var_id,
  m.timestamp,
  m.value,
  m.flag
FROM mesonet_measurements m
JOIN mesonet_stations s ON s.station_id = m.station_id
WHERE m.station_id = '0115'
  AND m.var_id = 'RF_1_Tot300s'
  AND m.timestamp >= '2023-03-04T00:00:00+00'
  AND m.timestamp < '2023-03-08T00:00:00+00'
  AND m.value IS NOT NULL
ORDER BY m.timestamp;

-- Also confirmed via direct HCDP API call:
-- curl "https://api.hcdp.ikewai.org/mesonet/db/measurements?station_ids=0115&var_ids=RF_1_Tot300s
--   &start_date=2023-03-05T00:00:00-10:00&end_date=2023-03-06T23:59:59-10:00&row_mode=json&limit=100000"
-- Result: 401 readings total; 250 readings of value=7999, 151 readings of value=0
-- All 7999 readings have flag=0 (not flagged as bad by HCDP)
