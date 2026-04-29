# Query: Data Quality Audit on mesonet_measurements

**Date:** 2026-04-29 04:30 UTC

---

## Preliminary: Schema Confirmation

```
Column     | Type                     | Nullable
-----------|--------------------------|--------
station_id | text                     | yes
var_id     | text                     | yes
timestamp  | timestamp with time zone | yes
value      | double precision         | yes
flag       | text                     | yes
```

- **value**: `double precision`, NULLs allowed
- **flag**: `text` column exists — but is **entirely useless**: 100.00% of 975.6M rows have `flag = '0'`. HCDP does not set quality flags. All QC must be done by the consumer.

---

## Check 1: NULL Values

### 1a. Table-wide NULL count

| null_count | total | null_pct |
|-----------|-------|----------|
| 1,317,006 | 975,631,825 | **0.1350%** |

**Interpretation: Expected.** 1.3M NULLs out of 975M rows is a 0.135% rate — low and consistent with normal sensor gaps (communication drops, maintenance windows).

### 1b. NULLs per station (top 10 worst)

| Station | Name | Nulls | Total | Null % | Interpretation |
|---------|------|-------|-------|--------|---------------|
| 0143 | Nakula | 130,217 | 5.6M | 2.32% | **Suspect** — high-altitude Maui station, intermittent comms |
| 0532 | Palolo Mauka | 6,485 | 308k | 2.10% | **Expected** — known stale station, limited data |
| 0153 | Haleakala Summit | 280,692 | 22.4M | 1.25% | **Expected** — extreme altitude (2984m), harsh conditions |
| 0119 | Kula Ag Station | 241,760 | 22.4M | 1.08% | **Suspect** — moderate elevation, higher than peers |
| 0152 | Nene Nest | 199,993 | 20.1M | 1.00% | **Expected** — high altitude (2593m) |

Most stations are 0.00-0.60% — very clean. The high-NULL stations are all high-altitude or known-problematic.

### 1c. NULLs per variable (top problematic)

| Variable | Nulls | Total | Null % | Interpretation |
|----------|-------|-------|--------|---------------|
| WG_1_TMx | 1,000,065 | 1,000,065 | **100%** | **Expected** — timestamp variable, not a measurement. Always NULL. |
| WS_1_TMx | 288,373 | 288,484 | 99.96% | **Expected** — same (timestamp of max wind speed). |
| CellOperator | 6,485 | 7,080 | 91.6% | **Expected** — cellular network metadata, not a measurement. |
| LGR_LiBattV | 22,083 | 1.66M | 1.33% | **Suspect** — logger battery voltage. Some stations don't report this. |

All other measurement variables are 0.00% NULL. The high-NULL variables are metadata/diagnostic fields, not weather measurements.

---

## Check 2: Sentinel Values

### 2a. Classic sentinel counts

| Value | Rows | Stations | Variables | Interpretation |
|-------|------|----------|-----------|---------------|
| **7999** | **342,148** | 32 | 14 | **Error** — sensor overflow/fault code. Dominant issue. |
| **-9999** | **12,680** | 1 | 6 | **Error** — classic missing-data sentinel at station 0532 only |
| 999 | 218 | 7 | 15 | **Suspect** — could be legitimate values for some variables |
| -999 | 7 | 2 | 2 | **Error** — but negligible count |

### 2b. 7999 sentinel breakdown (top sources)

| Station | Variable | Rows | Interpretation |
|---------|----------|------|---------------|
| 0122 (Kaehu) | SM_1_Avg | 95,964 | **Error** — persistent soil moisture sensor failure |
| 0122 | SM_2_Avg | 95,964 | **Error** — same station, second sensor also broken |
| 0531 (Kaluanui) | SM_3_Avg | 39,212 | **Error** — soil moisture probe 3 failure |
| 0122 | SHFsrf_1_Avg | 34,708 | **Error** — soil heat flux sensor failure at same station |
| 0122 | SM_3_Avg | 30,581 | **Error** — third soil sensor also broken (station 0122 is a wreck) |
| 0541 (Kaaawa) | SM_3_Avg | 20,626 | **Error** — soil probe 3 failure |
| 0115 (Piiholo) | RF_1_Tot60s | 1,319 | **Error** — the known rain gauge failure (March 2023) |

**Station 0122 (Kaehu, Maui) accounts for 63% of all 7999 sentinels** — its soil moisture and soil heat flux sensors are comprehensively broken.

### -9999 sentinel: all from station 0532 (Palolo Mauka)

| Station | Variables | Rows |
|---------|----------|------|
| 0532 | WS_1_Avg, WDrs_1_Avg, WS_1_Max, Trh_1_Avg, SWin_1_Avg, Tair_1_Avg | 12,680 |

Station 0532 uses -9999 as its error sentinel (different from the 7999 used by most stations).

---

## Check 3: Physical-Range Violations

### Summary of violations by variable type

| Category | Variable(s) | Violations | Root cause |
|----------|------------|------------|-----------|
| **Pressure** | P_1_Avg, Psl_1_Avg | 27.4M | **FALSE ALARM** — P_1_Avg is in kPa not hPa. 100 kPa = 1000 hPa. All values are normal. |
| **LW radiation** | LWinUC_1_Avg, LWoutUC_1_Avg | 1.88M | **Expected** — uncalibrated longwave readings; negative values are raw sensor voltage offsets |
| **LW radiation** | LWin_1_Avg, LWout_1_Avg | 350k | **Error** — includes values of 4.3×10²⁹ (inf/overflow) and large negatives |
| **Humidity (enclosure)** | RHenc | 134k | **Error** — enclosure RH reading, -65 to 155% (sensor failure) |
| **Soil moisture** | SM_1/2/3_Avg | 336k | **Error** — the 7999/9999998 sentinels counted again here |
| **Temperature** | Tair_1/2_Avg/Min/Max | 364k | **Error** — includes -9999 sentinels, -230°C, +145°C. Mix of sentinels and sensor faults. |
| **Humidity** | RH_1/2_Avg/Min/Max | 273k | **Error** — includes -999900, 5280%, and 1000%. Sensor failures. |
| **SW radiation** | SWin/out_1_Avg | 22k | **Error** — -9999 sentinels + physical overflow values |
| **Battery** | BattVolt | 7,928 | **Suspect** — 0V (power loss) and >16V (charging spikes) |
| **Wind speed** | WS/WSrs_1_Avg/Max | 8k | **Error** — -9999 sentinels + 479.9 m/s spikes |
| **Rainfall** | RF_1_Tot300s, RF_1_Tot60s | 1,569 | **Error** — the known 7999 sentinel at station 0115 |

### Negative rainfall

**Zero rows.** No negative rainfall values exist in the database. This is clean.

### Key correction: Pressure is NOT violated

The P_1_Avg variable is in **kPa** (confirmed: sea-level stations read ~100.0-100.3). The original range check assumed hPa (850-1050), which flagged 27.4M rows as violations. These are all valid. Correct range for P_1_Avg would be 60-105 kPa. Psl_1_Avg (sea-level-adjusted) is also kPa.

---

## Check 4: Stuck Sensors

### Temperature (Tair_1_Avg) — last 6 months

**Zero stuck runs found** (≥48 consecutive identical values). Temperature sensors are behaving normally.

### Relative humidity (RH_1_Avg) — last 6 months

**20 stuck runs found**, all at value = **100.00%**:

| Station | Name | Longest run | Duration |
|---------|------|-------------|----------|
| 0521 | Kaala (1205m) | 3,682 readings | **12.8 days** |
| 0134 | Hanaula (1215m) | 2,080 readings | 7.2 days |
| 0161 | Pohaku Palaha (2460m) | 1,737 readings | 6.0 days |
| 0153 | Haleakala Summit (2984m) | 1,077 readings | 3.7 days |
| 0532 | Palolo Mauka (714m) | 1,075 readings | 3.7 days |
| 0251 | Kehena Ditch Cabin (1158m) | 1,004 readings | 3.5 days |
| 0412 | Honoulimaloo (402m) | 870 readings | 3.0 days |

**Interpretation: Mostly expected.** All are at high-altitude cloud-immersion stations where RH genuinely sits at 100% for days during persistent cloud/fog events. Kaala (1205m, Oahu's highest peak) is famously fog-bound. However, runs exceeding ~7 days at exactly 100.0000% are **suspect** — real 100% RH would show slight fluctuations (100.02, 99.98, etc.). The sensor may be saturated/condensed and unable to read below 100%.

---

## Check 5: Statistical Outliers (5σ from station mean)

### Top findings

| Station | Variable | 5σ count | Min extreme | Max extreme | Interpretation |
|---------|----------|----------|-------------|-------------|---------------|
| 0153 | Tair_1_Avg | 10,471 | -175.3°C | -65.0°C | **Error** — impossible temperatures, sensor fault |
| 0541 | SM_1_Avg | 7,732 | 9999998 | 9999998 | **Error** — 7999/9999998 sentinels |
| 0288 | Tair_1_Avg | 3,246 | -39.95°C | 34.3°C | **Suspect** — -40°C is impossible in Hawaii |
| 0253 | Tair_1_Avg | 2,415 | -100.0°C | -62.6°C | **Error** — impossible temperatures |
| 0253 | RH_1_Avg | 2,241 | -100.0% | -51.1% | **Error** — negative humidity impossible |

Most RF_1_Tot300s "outliers" (1,500-3,100 per station) are **false flags** — real heavy rain events at mean ~0.03mm produce 5σ flags at ~1mm. These are legitimate readings during storms.

---

## Check 6: Flag Distribution

| flag | rows | pct |
|------|------|-----|
| 0 | 975,631,825 | 100.00% |

**The flag column is entirely useless.** Every single row in the database has `flag = '0'`. HCDP does not perform QC flagging at the source. All quality control must be done by the consumer.

---

## Data Quality Summary

### Estimated bad-data rows

| Category | Rows | % of table |
|----------|------|-----------|
| NULLs (legitimate gaps) | 1,317,006 | 0.135% |
| 7999 sentinels | 342,148 | 0.035% |
| -9999 sentinels | 12,680 | 0.001% |
| Other sentinels (9999998) | ~200,000 | 0.020% |
| Physical range violations (real, excluding pressure false alarm) | ~850,000 | 0.087% |
| Stuck RH sensors (ambiguous) | ~30,000 | 0.003% |
| **Total definite bad data** | **~1,400,000** | **~0.14%** |
| **Total including NULLs** | **~2,700,000** | **~0.28%** |

**The database is 99.86% clean by value quality.** Bad data is concentrated at a few stations and variables.

### Top 5 stations by quality issues

| Station | Name | Primary issues |
|---------|------|---------------|
| **0122** | Kaehu, Maui | 63% of all 7999 sentinels. SM, SHF sensors comprehensively broken. |
| **0532** | Palolo Mauka, Oahu | All -9999 sentinels. Offline since Feb 2026. Multiple sensor failures. |
| **0153** | Haleakala Summit, Maui | 10,471 impossible temperature readings (-175°C). High-altitude stress. |
| **0541** | Kaaawa Makai, Oahu | 9999998 sentinels in SM_1_Avg and SM_3_Avg. |
| **0253** | Puuloa, Hawaii | Impossible negative temperatures and humidity readings. |

### Top 5 variables by quality issues

| Variable | Issue | Affected rows |
|----------|-------|--------------|
| **SM_1/2/3_Avg** | 7999 and 9999998 sentinels from broken soil probes | ~336k |
| **LWin/out_1_Avg** | Overflow values (4.3×10²⁹), large negatives | ~350k |
| **Tair_1/2_Avg/Min/Max** | -9999 sentinels + impossible temps (-230°C, +145°C) | ~364k |
| **RH_1/2_Avg/Min/Max** | -999900, +5280% values; 100% saturation runs | ~273k |
| **SHFsrf_1_Avg** | 7999 sentinels at stations 0122, 0541, 0121, 0118 | ~40k |

### Do materialized views filter bad data?

**No.** The `mv_daily_station_summary` definition (inspected) contains **zero QC filters**. It sums/averages all raw values including:
- 7999 sentinel codes → inflates `rainfall_mm`, `soil_moisture_avg`
- -9999 sentinels → deflates `tair_min`, `wind_speed_avg`
- 9999998 sentinels → inflates `soil_moisture_avg`
- Impossible temperatures → contaminates `tair_min`, `tair_max`, `tair_avg`

The `mv_monthly_station_summary` aggregates from the daily view — inheriting all contamination.

**All downstream analysis using these materialized views must apply post-hoc filters** (exclude station 0115 for rainfall, station 0122 for soil moisture, etc.) or the views need to be rebuilt with QC filters in the definition.
