# Query: Why don't the chatbot's "10 driest May stations" match the HCDP portal?

**Date:** 2026-06-18 10:10 UTC
**Scope:** read-only diagnostic. Traced the chatbot's driest-station ranking back through the
code path and reproduced it against the live Postgres DB to explain the discrepancy with the
HCDP portal. No writes, no service/firewall/data changes. No secrets printed (queried via
`sudo -u postgres`).

---

## The user's observation

The chatbot returned a "10 driest mesonet stations for May" list (Kawaihae ~1.9, then 5–23 mm).
On the HCDP portal the user sees many stations in the yellow band and several **under 1 inch,
close to 0 in** — and asked how the chatbot is arriving at its numbers.

## Verdict

The chatbot's numbers are computed correctly **from the mesonet network**, but three things make
them look inconsistent with the portal: (1) it's a **different, sparser, much shorter-record
network** than the portal grids from, (2) it reports **millimeters** while the portal shows
**inches**, and (3) it **averages incomplete months with no completeness guard**, so a couple of
half-reported Mays wrongly land on the "driest" list.

---

## 1. Different station network than the portal

The ranking used the **mesonet** rollup `mv_monthly_station_summary_qc` (SUM of `RF_1_Tot300s`
5-minute tips per month), ~73 reporting stations, record starts ~2022.

The **portal** map is the gridded rainfall product built from the **legacy/historical gauge
network** — `historical_station_values` in the same DB:

```
historical May rainfall:  12,164 rows · 622 stations · 1990-05 → 2025-05
```

622 May-reporting gauges over 35 years vs. 10 mesonet points from a 2–5 year record → different
gauges in different places; the portal legitimately has many more near-zero leeward stations the
mesonet doesn't include.

## 2. Units: millimeters vs inches

`1 inch = 25.4 mm`. The chatbot's whole top-10 (1.9–23.3 mm) is **0.07–0.92 inch — all under 1
inch**, consistent with what the user sees. Kawaihae "1.9 mm" ≈ 0.07 in (essentially zero) — real.

## 3. The real flaw: averaging incomplete months without a completeness filter

The QC monthly view (`mv_monthly_station_summary_qc`) has **no `days_with_data` column / guard**.
Joining a per-May reporting-day count from `mv_daily_station_summary_qc` exposes the contamination:

| station | island | Mays averaged (mm / reporting days) | effect |
|---|---|---|---|
| **Kawaihae** | Hawaii | 31d + 31d → 1.9 | genuinely dry — **real** |
| **Kaʻehu** | Maui | 2025: 4.0 / **4 days** + 2026: 29.6 / 31 | partial month dragged avg → 16.8 |
| **Manukā** | (Unknown) | 2025: 9.4 / **10 days** + 2026: 27.2 / 31 | partial month dragged avg → 18.3 |
| **Olowalu** | Maui | 2024: **0 days** + 2025: 0.5 / 31 + 2026: 11.2 / 31 | one empty month + one suspiciously dry full month |

**Clean ranking (require ≥28 reporting days in every averaged May):** Kaʻehu and Manukā **drop out
of the top 10**; the rest of the order barely moves and Kawaihae stays #1. So the completeness
guard materially changes membership — those two were only "driest" because a half-reported May
undercounts the monthly total.

## 4. One value worth a QC flag

**Olowalu May 2025 = 0.5 mm over a full 31 days.** Either a real leeward-Maui dry spell or a
clogged/failed tipping bucket reading ~zero all month — a dead gauge and a bone-dry month look
identical in a SUM. Worth verifying before trusting it.

---

## How the value is actually produced (one line)

SUM 5-minute mesonet tips (`RF_1_Tot300s`) → monthly total per station → average across the 2–5
Mays each station has → rank lowest → report in mm. Correct arithmetic on the mesonet, but a
sparse/recent network with no incomplete-month filter.

## Schema note (minor)

`chatbot/hcdp_db_schema.py` documents the monthly view as `mv_monthly_station_summary` with a
`days_with_data` column, but the live DB has `mv_monthly_station_summary_qc` /
`mv_monthly_station_summary_raw` and the QC view has **no** `days_with_data` column and uses
`rainfall_mm` (not `rainfall_total_mm`). The schema doc is slightly stale vs. production.

## Suggested fixes (not applied — read-only diagnostic)

1. Point the "driest/wettest station" path at `historical_station_values` so results match the
   portal's network and 1990+ climatology.
2. Add a `days_reporting >= 28` guard to the mesonet monthly path so partial months stop
   contaminating "driest" rankings; consider exposing `days_with_data` on the QC monthly view.
3. QC-flag full-month near-zero totals (e.g. Olowalu 2025) for dead/clogged-gauge review.
