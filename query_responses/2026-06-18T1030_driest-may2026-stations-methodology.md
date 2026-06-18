# Driest mesonet stations — May 2026: values + methodology (for query-pipeline review)

**Date:** 2026-06-18 10:30 UTC
**Audience:** Claude Code / engineers tuning how the chatbot answers "driest/wettest station"
questions. This documents the exact data path, the SQL, and the data-quality traps that a naive
ranking falls into. Read-only investigation; no code changed.

---

## Result — 10 driest mesonet stations, May 2026 (QC'd, completeness-filtered, bad gauge removed)

| # | Station | Island | mm | inch | Confidence |
|---|---|---|---|---|---|
| 1 | Haleakalā Summit | Maui | 0.0 | 0.00 | ⚠️ suspect (0.0 in May **and** June — likely stuck/failed gauge) |
| 2 | Kawaihae | Hawaiʻi | 0.0 | 0.00 | ✅ real (driest station statewide; June recovers to 22.4 mm) |
| 3 | Līpoa | Maui | 0.5 | 0.02 | ✅ real |
| 4 | Nāʻiwa | Molokaʻi | 2.8 | 0.11 | ✅ real |
| 5 | Anapuka | Molokaʻi | 5.4 | 0.21 | ✅ real |
| 6 | Pūlehu | Maui | 10.5 | 0.41 | ✅ real |
| 7 | Kahikinui | Maui | 10.8 | 0.42 | ✅ real |
| 8 | Olowalu | Maui | 11.2 | 0.44 | ✅ real |
| 9 | Lahaina Water Treatment Plant | Maui | 11.7 | 0.46 | ✅ real |
| 10 | Upper Kahikinui | Maui | 13.7 | 0.54 | ✅ real |

Next in line: Kualapuʻu (Molokaʻi) 14.6 mm / 0.58 in.
**Excluded:** Waipā (Kauaʻi) 0.8 mm — see "Trap 3" below (failed gauge, not dry).

All values are **millimeters** in the DB; inches = mm / 25.4. Geography is exactly right (leeward
Maui / Molokaʻi / Kohala rain shadows).

---

## Methodology

### Which network
- Used the **mesonet** network: materialized view `mv_monthly_station_summary_qc`
  (`rainfall_mm` = SUM of `RF_1_Tot300s` 5-minute tips over the HST month).
- ~73 reporting stations, record starts ~2022.
- This is the **only** network with **May 2026** published. The portal's gridded product is built
  from `historical_station_values` (legacy/historical gauge network, ~622 May-reporting stations,
  1990→**2025-05** only). For any current-month question the mesonet is the sole source; for
  portal-matching historical questions, use `historical_station_values`.

### Single month, not a multi-year average
This is `month = '2026-05-01'` only. (A prior "driest" answer averaged each station across the 2–5
Mays it has, which mixed in partial months — see Trap 1.)

### Completeness guard
Required **≥28 reporting days** in May 2026, computed from `mv_daily_station_summary_qc`, to drop
partial-month undercounts.

### Final query
```sql
WITH d AS (
  SELECT station_id,
         count(*) FILTER (WHERE rainfall_mm IS NOT NULL) AS days_rep
  FROM mv_daily_station_summary_qc
  WHERE date_hst >= '2026-05-01' AND date_hst < '2026-06-01'
  GROUP BY 1
)
SELECT m.station_name, m.island,
       round(m.rainfall_mm::numeric, 1)        AS may2026_mm,
       round((m.rainfall_mm/25.4)::numeric, 2) AS may2026_in,
       d.days_rep
FROM mv_monthly_station_summary_qc m
JOIN d USING (station_id)
WHERE m.month = '2026-05-01'
  AND d.days_rep >= 28
ORDER BY m.rainfall_mm ASC
LIMIT 10;
```

---

## Data-quality traps the pipeline must handle (the important part)

### Trap 1 — averaging incomplete months (silently undercounts)
The monthly QC view has **no `days_with_data` column**. Averaging a station's Mays without a
completeness guard pulls in partial months as if they were full:
- Kaʻehu May 2025 = 4.0 mm over **4 reporting days**; May 2026 = 29.6 mm / 31 days.
- Manukā May 2025 = 9.4 mm over **10 days**; May 2026 = 27.2 mm / 31 days.

Both were ranked "driest" in the earlier averaged answer purely because of the half-reported month.
A `days_rep >= 28` filter ejects them. **Fix: expose `days_with_data` on the monthly MV, or always
join the daily reporting count.**

### Trap 2 — units (mm vs inches)
DB is mm; the portal/users think in inches. The whole top-10 here is < 1 inch (0.00–0.54 in).
Always state units and offer the inch conversion (÷ 25.4) in user-facing output.

### Trap 3 — stuck-at-zero gauges survive the completeness filter (the subtle one)
A clogged/failed tipping bucket still *reports* a value (0.0) every interval, so
`days_rep = 31` even though the data is wrong. The ≥28-day filter cannot catch it.
- **Waipā (Kauaʻi, 22.20°N −159.52°, 5 m)** — Hanalei north shore, one of the **wettest** spots in
  the state. 2026 run: `Feb 355 → Mar 93 → Apr 71 → May 0.8 → Jun 0.5 mm`. A north-shore gauge going
  from 71 mm to ~0 for two straight months is a near-certain sensor failure, not drought. It
  wrongly ranked #4 until removed by domain check.
- **Haleakalā Summit** — exactly `0.0` in **May and June** after 153 mm in April; same stuck-zero
  signature (though above-inversion summer dryness is *possible*, so flag-don't-drop).
- Contrast **Kawaihae** — `0.0` in May but **June recovers to 22.4 mm**, proving the gauge works;
  its zero is real.

**Fix ideas for Trap 3:** flag full-month exact-zeros (and ≥2 consecutive zero months) for review;
optionally cross-check a "driest" candidate against its own neighboring months and/or the gridded
product before presenting it as fact; sanity-bound against climatology (a 5 m north-shore Kauaʻi
station reading 0 mm/month is implausible).

---

## Recommendations for the query system

1. **Default current-month / recent queries to the mesonet QC views; default historical/climatology
   and portal-matching queries to `historical_station_values`.** Make the network choice explicit in
   the answer so users know which gauge set they're seeing.
2. **Always apply a completeness guard** (`days_rep >= 28` monthly) and **never average across
   partial months** without it.
3. **Add a zero-gauge sanity layer** for "driest" rankings: flag full-month exact-zeros, consecutive
   zero months, and values that contradict the station's own recent months or local climatology.
4. **Report mm and inches**, and name the period explicitly (single month vs multi-year average).
5. **Schema doc drift:** `chatbot/hcdp_db_schema.py` references `mv_monthly_station_summary` with a
   `days_with_data` column and `rainfall_total_mm`. Production actually has
   `mv_monthly_station_summary_qc` / `_raw`, the QC view uses `rainfall_mm`, and there is **no**
   `days_with_data` column. Update the doc so the SQL agent stops emitting queries against the old
   names/columns.

---

## Provenance
Mesonet QC views in the HCDP Postgres DB (`mv_monthly_station_summary_qc`,
`mv_daily_station_summary_qc`); historical coverage from `historical_station_values`. Queried
read-only. No secrets in this document.
