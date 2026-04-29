# Methodology Guide: How to Avoid Wrong Answers

## Pitfall 1: Network composition bias (CRITICAL)

**The most dangerous error in this database.** The number and type of reporting stations changes dramatically over time. A naive "average all stations" approach can produce answers that reflect changes in which stations are reporting, not changes in weather.

### The problem

| Year | Oahu stations | Statewide stations |
|------|--------------|-------------------|
| 2010 | 124 | 450 |
| 2019 | 136 | 429 |
| 2022 | 54 | 163 |
| 2025 | 62 | 228 |

The COOP volunteer observer network collapsed between 2019-2022. On Oahu, COOP went from 46 stations to 1. If COOP stations were systematically in wetter or drier locations than the remaining HydroNet/RAWS stations, a naive average would show a false trend.

### The solution: stable reference panels

For any cross-year comparison, build a panel of stations that reported consistently across the comparison period:

```sql
-- Find stations that reported in at least 20 of 26 years AND in the target year
WITH panel AS (
  SELECT station_id
  FROM historical_station_values
  WHERE datatype = 'rainfall'
    AND EXTRACT(YEAR FROM date) BETWEEN 2000 AND 2025
  GROUP BY station_id
  HAVING COUNT(DISTINCT EXTRACT(YEAR FROM date)) >= 20
),
panel_with_target AS (
  SELECT DISTINCT p.station_id
  FROM panel p
  JOIN historical_station_values h ON h.station_id = p.station_id
  WHERE h.datatype = 'rainfall' AND EXTRACT(YEAR FROM h.date) = <TARGET_YEAR>
)
SELECT
  EXTRACT(YEAR FROM h.date)::int AS year,
  COUNT(DISTINCT h.station_id) AS stations,
  ROUND((AVG(h.value) * 12)::numeric, 0) AS est_annual_mm
FROM historical_station_values h
JOIN panel_with_target p ON p.station_id = h.station_id
WHERE h.datatype = 'rainfall'
GROUP BY EXTRACT(YEAR FROM h.date)
ORDER BY year;
```

### When you DON'T need a reference panel

- Single-year analysis (e.g., "what was the wettest day in March 2026") — no cross-year comparison, no bias
- Mesonet-only analysis within a period where station count was stable (2025-2026, both at 78 stations)
- Questions about a single station over time

### When you MUST use a reference panel

- "Was 2022 drier than 2010?" — comparing across the COOP collapse
- "Is rainfall trending down?" — any multi-decade trend analysis
- "What was the driest year?" — ranking years with different station counts

## Pitfall 2: Daily totals vs hourly intensity for flood risk

**Daily rainfall totals are a poor proxy for flood risk.** Two days with the same 150mm total can have completely different flood outcomes:

- Day A: 150mm spread over 20 hours (7.5 mm/hr) → drainage handles it, no flooding
- Day B: 150mm in a 3-hour burst (50 mm/hr) → overwhelms storm drains, flash flooding

For flood-risk questions, always check **hourly intensity**:
```sql
SELECT date_trunc('hour', timestamp) AS hour,
  SUM(value) AS hourly_mm
FROM mesonet_measurements
WHERE station_id = '<sid>' AND var_id = 'RF_1_Tot300s'
  AND value < 7000
  AND timestamp >= '<start>' AND timestamp < '<end>'
GROUP BY date_trunc('hour', timestamp)
ORDER BY SUM(value) DESC
LIMIT 10;
```

Also check **antecedent soil moisture** — saturated soil (VWC >55%) means all rainfall becomes runoff:
```sql
SELECT date_trunc('day', timestamp)::date AS day,
  ROUND(AVG(value)::numeric, 3) AS avg_vwc
FROM mesonet_measurements
WHERE station_id = '<sid>' AND var_id = 'SM_1_Avg'
  AND value < 1  -- exclude sentinel
  AND timestamp BETWEEN '<event_date>'::date - 7 AND '<event_date>'::date + 1
GROUP BY date_trunc('day', timestamp)::date
ORDER BY day;
```

## Pitfall 3: Historical monthly data is not storm data

The `historical_station_values` table has **monthly resolution only**. You cannot isolate multi-day events (hurricanes, atmospheric rivers) from monthly totals.

For events before 2022 (when mesonet data starts), you can:
1. Use the monthly total as a **proxy** for the storm contribution
2. Subtract the station's typical monthly rainfall to estimate the **excess** attributable to the event
3. **Always caveat** that this overestimates the actual storm total because non-event rain is included

Example for Hurricane Lane (August 2018):
```sql
-- Monthly total
SELECT value AS aug_2018_mm FROM historical_station_values
WHERE station_id = '140.5' AND date = '2018-08-01' AND datatype = 'rainfall';
-- Result: 2166mm

-- Normal August at this station
SELECT AVG(value) FROM historical_station_values
WHERE station_id = '140.5' AND datatype = 'rainfall'
  AND EXTRACT(MONTH FROM date) = 8 AND EXTRACT(YEAR FROM date) != 2018;
-- Result: ~475mm

-- Lane excess ≈ 2166 - 475 = 1691mm (~67 inches)
-- Published daily storm total: 50-58 inches (monthly proxy overestimates ~15-30%)
```

## Pitfall 4: HST vs UTC timestamps

Mesonet timestamps are stored in **UTC**. Hawaii Standard Time is **UTC-10** year-round (no daylight saving).

- A reading at `2026-03-14 08:00:00+00` (UTC) = `2026-03-13 10:00:00 PM HST` — **the previous calendar day in Hawaii**
- When aggregating by day, use `timestamp AT TIME ZONE 'Pacific/Honolulu'` or use `mv_daily_station_summary.date_hst` (already HST-adjusted)

The materialized views use HST dates. Raw `mesonet_measurements` uses UTC.

## Pitfall 5: Elevation effects on station representativeness

A station at 600m reads ~4°C cooler than sea level. When a user asks about a town (Hilo, Honolulu), use the **lowest-elevation nearby station**, not necessarily the closest by name.

Temperature lapse rate: **−6.5°C per 1,000m** (approximate, varies with humidity and inversion layer).

Example: Piihonua (0213, 606m, reads 18°C) is near Hilo but at elevation. Downtown Hilo (~10m) would be approximately 18 + (596 × 6.5/1000) ≈ 22°C. Use IPIF (0281, 112m) as a better proxy for downtown conditions.

## Pitfall 6: "Wettest/driest station" rankings are contaminated

Station 0115 (Piiholo, Maui) appears as the wettest station by far in any unfiltered ranking, because 1,999,750mm of 7999 sentinel codes are summed into its total. **Always exclude station 0115 or filter value < 7000 before ranking stations by rainfall.**

Similarly, station 0122 will top any soil moisture ranking with VWC of 7999.

## Checklist before answering

1. [ ] Am I filtering out 7999 sentinel codes?
2. [ ] Am I comparing years with different station counts? If yes, do I need a reference panel?
3. [ ] Am I using the right table? (MV for daily, raw for sub-daily, historical for pre-2022)
4. [ ] Am I reporting temperatures in the right units? (DB stores °C)
5. [ ] Am I using the right station for the location the user asked about?
6. [ ] If reporting "current weather," is the reading actually current (< 1 hour old)?
7. [ ] If ranking extremes, am I checking surrounding readings for isolated spikes?
