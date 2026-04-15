## Scientific context

Automated weather station networks routinely produce erroneous readings from sensor malfunctions, datalogger errors, clogged instruments, or electrical faults. Quality control (QC) is critical for any analysis built on these data. The HCDP mesonet uses tipping-bucket rain gauges that report cumulative rainfall over 5-minute intervals (variable `RF_1_Tot300s`).

## Investigation

The anomaly was discovered while comparing March rainfall across years. Station 0115 showed ~1,000,000 mm of rainfall on March 5-6, 2023 — obviously impossible.

### Evidence of sensor error:
1. **Constant value**: Exactly `7999` reported every 5 minutes for ~21 consecutive hours (250 readings)
2. **Sentinel code**: `7999` is a classic max-register/overflow value for datalogger firmware, indicating the sensor reported an out-of-range condition
3. **Physical impossibility**: 7999 mm in 5 minutes = 95,988 mm/hr. The world record rainfall intensity is ~305 mm/hr.
4. **No QC flag**: All readings have `flag=0`, meaning HCDP's automated QC did not catch this
5. **Station went offline**: No data from March 8-10, suggesting the sensor failure was eventually noticed
6. **Normal readings before/after**: March 4 shows typical values (mostly 0, occasional 0.257 mm tips)

### API confirmation:
Direct API query returned identical data — the bad values exist at the source, not from our ingestion process.

## Impact

Without filtering, this single sensor error inflates any aggregate rainfall statistic for Maui in March 2023 by ~2,000,000 mm. A simple QC rule (reject RF_1_Tot300s > 100) would catch this and similar errors. We also found station 0122 (Kaehu) reporting `7999` for soil moisture — the same error pattern on a different sensor type.

## Recommendations

- Filter `value = 7999` across all variables as a likely sensor error code
- More generally, apply physical bounds checking (e.g., rainfall > 200 mm/5min is impossible)
- Report unflagged errors to the HCDP team
