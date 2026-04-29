# Mesonet Variable Reference

The database has 279 variables. These are the ones you'll use 95% of the time:

## Primary weather variables

| var_id | Description | Units | Notes |
|--------|------------|-------|-------|
| **`RF_1_Tot300s`** | Rainfall, 5-minute total | mm | **Primary rainfall variable.** Cumulative rain in each 5-min interval. Sum for hourly/daily totals. |
| `RF_1_Tot60s` | Rainfall, 1-minute total | mm | Higher resolution, not available at all stations |
| **`Tair_1_Avg`** | Air temperature, average | °C | 5-minute average. Most-used temperature variable. |
| `Tair_1_Max` | Air temperature, maximum | °C | 5-minute maximum |
| `Tair_1_Min` | Air temperature, minimum | °C | 5-minute minimum |
| **`RH_1_Avg`** | Relative humidity | % | 5-minute average. Range 0-100. |
| **`WS_1_Avg`** | Wind speed, scalar average | m/s | Multiply by 2.237 for mph |
| `WD_1_Avg` | Wind direction | degrees | Meteorological convention (0=N, 90=E, 180=S, 270=W) |
| **`SM_1_Avg`** | Soil volumetric water content | m³/m³ | Range 0-1. Multiply by 100 for percentage. >0.50 = near saturation. |
| `SM_2_Avg` | Soil VWC, sensor 2 | m³/m³ | Different depth. Not all stations have this. |
| `SM_3_Avg` | Soil VWC, sensor 3 | m³/m³ | Different depth. Rare. |
| `SMadjT_1_Avg` | Soil VWC, temp-adjusted | m³/m³ | Temperature-corrected version |
| `SRad_1_Avg` | Solar radiation | W/m² | Average incoming shortwave |
| `BP_1_Avg` | Barometric pressure | hPa | Not available at all stations |
| `Tsoil_1_Avg` | Soil temperature | °C | At sensor probe depth |

## Sensor metadata variables (usually not needed for analysis)

Variables like `SM1_depth0`, `SM1_depthM`, `SM1_ori`, `NO_Tsoil`, etc. describe sensor installation characteristics (depth, orientation, count). These are static metadata, not time-varying measurements.

## Aggregating rainfall

**Daily total:**
```sql
SELECT station_id, date_trunc('day', timestamp)::date AS day,
  SUM(value) AS daily_rainfall_mm
FROM mesonet_measurements
WHERE var_id = 'RF_1_Tot300s' AND value IS NOT NULL AND value < 7000
GROUP BY station_id, date_trunc('day', timestamp)::date;
```
Or use `mv_daily_station_summary.rainfall_mm` (pre-computed, much faster).

**Hourly total:**
```sql
SELECT station_id, date_trunc('hour', timestamp) AS hour,
  SUM(value) AS hourly_mm
FROM mesonet_measurements
WHERE var_id = 'RF_1_Tot300s' AND value IS NOT NULL AND value < 7000
GROUP BY station_id, date_trunc('hour', timestamp);
```

**ALWAYS add `AND value < 7000`** to rainfall queries to exclude the 7999 sentinel code.

## Historical station variables

The `historical_station_values` table uses different variable encoding:

| datatype | aggregation | What it is |
|----------|-------------|-----------|
| `rainfall` | NULL | Monthly total rainfall (mm) |
| `temperature` | `max` | Monthly average of daily max temperature (°C) |
| `temperature` | `min` | Monthly average of daily min temperature (°C) |

Filter with `WHERE datatype = 'rainfall'` or `WHERE datatype = 'temperature' AND aggregation = 'max'`.

## Unit conversions

| From | To | Multiply by |
|------|----|-------------|
| mm | inches | 0.03937 (or divide by 25.4) |
| °C | °F | × 9/5 + 32 |
| m/s | mph | 2.237 |
| m/s | knots | 1.944 |
| m³/m³ | % VWC | × 100 |
