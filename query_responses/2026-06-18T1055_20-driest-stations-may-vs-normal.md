# 20 driest Hawaiian stations: May average vs. 1991–2010 normal + methodology

**Date:** 2026-06-18 10:55 UTC
**Scope:** read-only analysis. Ranked the 20 driest mesonet stations by their May average and
compared each to the 1991–2010 May rainfall normal sampled at the station's coordinate. No code,
service, firewall, or data changes. No secrets in this document.

---

## Result

May avg = mean of complete-May totals over the station's mesonet record (n = # of Mays).
Normal = 1991–2010 May rainfall climatology sampled at the station point. % = avg ÷ normal.
Anomaly = avg − normal (mm). All values in **mm** (÷ 25.4 for inches).

| # | Station | Island | n | May avg mm | Normal mm | % of normal | Anomaly mm |
|---|---|---|---|---|---|---|---|
| 1 | Kawaihae | Hawaiʻi | 2 | 1.9 | 10.9 | 17% | −9.0 |
| 2 | Nāʻiwa | Molokaʻi | 1 | 2.8 | 13.3 | 21% | −10.4 |
| 3 | Olowalu | Maui | 2 | 5.8 | 11.5 | 51% | −5.7 |
| 4 | Līpoa | Maui | 3 | 7.0 | 16.9 | 41% | −10.0 |
| 5 | Lahaina Water Treatment Plant | Maui | 3 | 11.3 | 15.5 | 73% | −4.3 |
| 6 | Kualapuʻu | Molokaʻi | 1 | 14.6 | 24.9 | 59% | −10.3 |
| 7 | Anapuka | Molokaʻi | 3 | 16.4 | 28.3 | 58% | −12.0 |
| 8 | Kaluanui Ridge | Oʻahu | 2 | 22.1 | 45.0 | 49% | −22.9 |
| 9 | Haleakalā Summit | Maui | 5 | 22.6 | 34.4 | 66% | −11.8 |
| 10 | Pūlehu | Maui | 3 | 23.3 | 20.1 | 116% | +3.2 |
| 11 | Puʻuloa | Hawaiʻi | 2 | 23.8 | 49.6 | 48% | −25.8 |
| 12 | Kula Agricultural Experiment Station | Maui | 5 | 24.2 | 30.9 | 78% | −6.7 |
| 13 | Kahikinui | Maui | 4 | 27.1 | 38.8 | 70% | −11.7 |
| 14 | Manukā | (Unknown) | 1 | 27.2 | 28.5 | 95% | −1.3 |
| 15 | Kaʻehu | Maui | 1 | 29.6 | 26.8 | 111% | +2.9 |
| 16 | Nēnē Nest | Maui | 4 | 31.6 | 29.7 | 107% | +1.9 |
| 17 | Keōpukaloa | (Unknown) | 2 | 33.4 | 47.0 | 71% | −13.7 |
| 18 | Auwahi | Maui | 3 | 36.1 | 42.6 | 85% | −6.4 |
| 19 | Pālamanui | Hawaiʻi | 4 | 42.5 | 48.3 | 88% | −5.8 |
| 20 | Kealakekua | Hawaiʻi | 3 | 46.1 | 54.2 | 85% | −8.1 |

### Findings
- **16 of 20 are below their May normal.** The driest stations have been running *drier than
  usual*, not merely dry by climate. Kawaihae (17% of normal) and Nāʻiwa (21%) are extreme — arid
  locations also far under their own dry normal.
- **4 are at/above normal** (Pūlehu 116%, Kaʻehu 111%, Nēnē Nest 107%, Manukā 95%): climatologically
  dry spots whose recent Mays were near normal. They make the "driest" list on absolute total, not
  on being anomalously dry.
- **Island distribution:** Maui 11, Hawaiʻi 4, Molokaʻi 3, Oʻahu 1, plus 2 with missing island
  metadata. Concentration in leeward Maui / Molokaʻi / Kohala–Kona is exactly the expected rain-
  shadow geography.

---

## Methodology

### 1. Ranking the driest stations (the "May average")
- Source: **mesonet** network, `mv_monthly_station_summary_qc` (`rainfall_mm` = SUM of
  `RF_1_Tot300s` 5-minute tips over the HST month). Record ~2022→present.
- **Completeness guard:** only Mays with **≥28 reporting days** (counted from
  `mv_daily_station_summary_qc`) are included, so partial months don't undercount the average.
- Per station, average those complete Mays; rank ascending; take 20. `n` = number of complete Mays
  averaged (1–5).

```sql
WITH d AS (
  SELECT station_id, date_trunc('month',date_hst) mon,
         count(*) FILTER (WHERE rainfall_mm IS NOT NULL) days_rep
  FROM mv_daily_station_summary_qc WHERE EXTRACT(MONTH FROM date_hst)=5 GROUP BY 1,2
),
mays AS (
  SELECT m.station_id, m.station_name, m.island, m.rainfall_mm
  FROM mv_monthly_station_summary_qc m
  JOIN d ON d.station_id=m.station_id AND d.mon=m.month
  WHERE EXTRACT(MONTH FROM m.month)=5 AND d.days_rep>=28
)
SELECT a.station_name, a.island, s.lat, s.lng,
       count(*) n_mays, round(avg(a.rainfall_mm)::numeric,2) may_avg_mm
FROM mays a JOIN mesonet_stations s ON s.station_id=a.station_id
GROUP BY a.station_name, a.island, s.lat, s.lng
ORDER BY may_avg_mm ASC LIMIT 20;
```

### 2. The "normal"
- Source: HCDP **1991–2010 May rainfall climatology** grid,
  `rainfall_climatology_1991_2010_month05.tif` (registered in the `climatology_rasters` table;
  same baseline the raster service's anomaly endpoints use). CRS EPSG:4326, units mm/month,
  nodata −9999.
- **Sampled at each station's (lng, lat)** with rasterio (nearest-pixel `ds.sample`).
- Derived columns: `pct = 100·avg/normal`, `anomaly = avg − normal`.

This is the apples-to-apples reference because the mesonet stations (2022+) have no long-term
record of their own; the climatology supplies the 20-year May expectation at each location.

---

## Caveats (important for interpretation and for the query pipeline)

1. **Selection bias toward below-normal.** Ranking by lowest recent average preferentially selects
   stations/years that were anomalously dry, which is part of why 16/20 land under 100% of normal.
   A below-normal % here is *not* by itself proof of regional drought.
2. **Short, uneven record.** Several stations have **n = 1** complete May (Nāʻiwa, Kualapuʻu,
   Manukā, Kaʻehu) — a single-year "average" with high variance. `n` is shown so this is visible.
3. **Point gauge vs. interpolated grid.** The normal is a gridded-interpolated value sampled at a
   point; a coastal/leeward pixel can differ from the exact gauge microclimate. Best available
   reference, but not a like-for-like gauge normal.
4. **Network mismatch with the portal.** This uses the mesonet; the HCDP portal grids from the
   legacy/historical gauge network (`historical_station_values`, 1990→2025-05). Different stations.
5. **Stuck-zero gauges.** The ≥28-day filter catches missing days but not a gauge stuck reporting
   0.0 (e.g. Waipā's May/June 2026 failure documented previously). None of those contaminate this
   multi-year average list, but the multi-year averaging also masks single-month failures — e.g.
   Haleakalā Summit's isolated 0.0 in May 2026 is absorbed into its 5-May average of 22.6 mm.
6. **Island metadata gaps.** Manukā and Keōpukaloa have `island = 'Unknown'` in `mesonet_stations`
   despite valid coordinates (Manukā ≈ South Kona/Kaʻū → Hawaiʻi). Worth backfilling.

---

## Provenance
HCDP Postgres DB: `mv_monthly_station_summary_qc`, `mv_daily_station_summary_qc`,
`mesonet_stations`, `climatology_rasters`. Normal grid:
`rainfall_climatology_1991_2010_month05.tif` (1991–2010 baseline), sampled with rasterio
(GDAL via the raster-service venv). Queried read-only.
