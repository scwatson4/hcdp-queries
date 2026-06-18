# 10 driest stations: March 2026 vs May 2026 (with normal comparison + gauge QC)

**Date:** 2026-06-18 11:30 UTC
**Scope:** read-only. Ranked the 10 driest mesonet stations for March 2026 and May 2026, each
single-month and ≥28-day complete, then compared every value to the 1991–2010 monthly normal
sampled at the station coordinate to separate genuine aridity from gauge failure and seasonality.
No code/service/firewall/data changes. No secrets in this document.

---

## Headline

The two months are a study in why "lowest total" ≠ "driest place":

- **May 2026 — genuinely dry.** Most of the list sits well below its May normal; leeward
  Maui / Molokaʻi / Kohala, exactly the right geography.
- **March 2026 — anomalously WET.** Every *functioning* gauge ran far **above** its March normal
  (Kawaihae 603%, Pālamanui 504%). The only stations below normal are three Kauaʻi **north-shore**
  gauges — the *wettest* climate in the state — which are **under-reporting / failing**, not dry.
  In a wet month, ranking by lowest total surfaces broken gauges, not arid places.

---

## March 2026 — "driest" 10 (QC'd; values in mm, inch in parentheses)

| # | Station | Island | Mar mm (in) | Mar normal mm | % of normal | Flag |
|---|---|---|---|---|---|---|
| 1 | Lower Limahuli | Kauaʻi | 89.9 (3.54) | 268.6 | 33% | ⚠️ suspect under-report (wet-climate gauge) |
| 2 | Waipā | Kauaʻi | 92.7 (3.65) | 227.2 | 41% | ⚠️ failing gauge (fully dead by May) |
| 3 | Common Ground | Kauaʻi | 134.2 (5.28) | 190.0 | 71% | ⚠️ suspect (north-shore Kauaʻi) |
| 4 | Kawaihae | Hawaiʻi | 164.6 (6.48) | 27.3 | 603% | ✅ real — but WET vs normal |
| 5 | Māmalahoa | Hawaiʻi | 198.6 (7.82) | 52.7 | 377% | ✅ real — wet vs normal |
| 6 | Kanakaleonui | Hawaiʻi | 226.1 (8.90) | 156.7 | 144% | ✅ real |
| 7 | Kaiāulu Puʻuwaʻawaʻa | Hawaiʻi | 239.8 (9.44) | 57.8 | 415% | ✅ real — wet vs normal |
| 8 | Manukā | (Unknown) | 267.2 (10.52) | 55.7 | 480% | ✅ real — wet vs normal |
| 9 | Kula Agricultural Experiment Station | Maui | 291.8 (11.49) | 71.0 | 411% | ✅ real — wet vs normal |
| 10 | ʻIole | Hawaiʻi | 318.2 (12.53) | 176.6 | 180% | ✅ real |

**Read this carefully:** the three lowest "driest" March stations are flagged Kauaʻi north-shore
gauges reading 33–71% of their wet normal while the rest of the state ran 150–600% of normal — a
near-certain under-catch, consistent with Waipā's later total failure. The genuinely lowest
*functioning* totals (leeward Big Island) were themselves **2–6× their March normal**, i.e. March
2026 had essentially **no genuinely dry station** — the "driest" label in March is mostly a gauge
artifact plus seasonality.

## May 2026 — driest 10 (QC'd)

| # | Station | Island | May mm (in) | May normal mm | % of normal | Flag |
|---|---|---|---|---|---|---|
| 1 | Kawaihae | Hawaiʻi | 0.0 (0.00) | 10.9 | 0% | ✅ real (driest station; June recovers to 22.4) |
| 2 | Haleakalā Summit | Maui | 0.0 (0.00) | 34.4 | 0% | ⚠️ suspect (0.0 in May **and** June) |
| 3 | Līpoa | Maui | 0.5 (0.02) | 16.9 | 3% | ✅ real |
| 4 | Waipā | Kauaʻi | 0.8 (0.03) | 121.8 | 1% | ⚠️ failed gauge — exclude (wet-climate, reads ~0) |
| 5 | Nāʻiwa | Molokaʻi | 2.8 (0.11) | 13.3 | 21% | ✅ real |
| 6 | Anapuka | Molokaʻi | 5.4 (0.21) | 28.3 | 19% | ✅ real |
| 7 | Pūlehu | Maui | 10.5 (0.41) | 20.1 | 52% | ✅ real |
| 8 | Kahikinui | Maui | 10.8 (0.42) | 38.8 | 28% | ✅ real |
| 9 | Olowalu | Maui | 11.2 (0.44) | 11.5 | 97% | ✅ real (normally this dry) |
| 10 | Lahaina Water Treatment Plant | Maui | 11.7 (0.46) | 15.5 | 75% | ✅ real |

May 2026 is genuinely dry: leeward stations at 0–52% of their (already low) May normal. Waipā's
0.8 mm against a 121.8 mm north-shore normal (1% of normal) is the clearest single proof of gauge
failure in the dataset. Haleakalā Summit's exact 0.0 in two consecutive months is flagged, not
endorsed.

---

## Methodology

- **Network:** mesonet, `mv_monthly_station_summary_qc` (`rainfall_mm` = SUM of `RF_1_Tot300s`
  5-minute tips over the HST month). Only network with 2026 months published (portal's historical
  network stops at 2025-05).
- **Single month**, not multi-year average: `month = '2026-03-01'` / `'2026-05-01'`.
- **Completeness guard:** ≥28 reporting days that month, from `mv_daily_station_summary_qc`.
- **Rank ascending**, take 10.
- **Normal:** HCDP 1991–2010 monthly climatology grids
  (`rainfall_climatology_1991_2010_month03.tif` / `…_month05.tif`, registered in
  `climatology_rasters`), sampled at each station's (lng, lat) with rasterio. `% of normal =
  100·month/normal`.

```sql
WITH d AS (
  SELECT station_id, count(*) FILTER (WHERE rainfall_mm IS NOT NULL) AS days_rep
  FROM mv_daily_station_summary_qc
  WHERE date_hst >= DATE :mon AND date_hst < (DATE :mon + INTERVAL '1 month')
  GROUP BY 1)
SELECT m.station_name, m.island,
       round(m.rainfall_mm::numeric,1) AS mm,
       round((m.rainfall_mm/25.4)::numeric,2) AS inch, d.days_rep
FROM mv_monthly_station_summary_qc m JOIN d USING (station_id)
WHERE m.month = DATE :mon AND d.days_rep >= 28
ORDER BY m.rainfall_mm ASC LIMIT 10;
```

## Why the normal comparison is essential (for the query pipeline)

A bare "driest station" ranking conflates three different things; only the normal disentangles them:

1. **Genuine aridity** — low total *and* low % of normal (Kawaihae, Olowalu in May).
2. **Seasonality** — March 2026 was wet, so even the lowest leeward totals are 2–6× normal; calling
   them "dry" is misleading without the seasonal/normal context.
3. **Gauge failure** — a wet-climate station reading far below its normal (Kauaʻi north-shore:
   Limahuli/Waipā/Common Ground in March; Waipā in May). The ≥28-day filter cannot catch a gauge
   stuck reporting near-zero — only a climatology/normal cross-check does.

**Recommendation:** for any "driest/wettest" answer, attach `% of normal` and flag (a) full-month
exact-zeros, (b) ≥2 consecutive zero/near-zero months, and (c) values that contradict the station's
own climatology (e.g. a wet-climate gauge < ~50% of normal). Present genuinely-dry vs. broken-gauge
separately rather than in one ranked list.

## Caveats
- Short mesonet record; several stations have few qualifying months.
- Point gauge vs. interpolated grid: the normal is a grid value at a point, not a co-located gauge
  normal — fine for cross-checks, not for exact bias correction.
- Island metadata gap: Manukā = `Unknown` despite valid coordinates (≈ South Kona/Kaʻū → Hawaiʻi).

## Provenance
HCDP Postgres: `mv_monthly_station_summary_qc`, `mv_daily_station_summary_qc`, `mesonet_stations`,
`climatology_rasters`. Normals: `rainfall_climatology_1991_2010_month03.tif` /
`…_month05.tif` (1991–2010 baseline), sampled with rasterio. Read-only.
