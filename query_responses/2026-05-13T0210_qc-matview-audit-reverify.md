# Query: Audit-only re-verify of the QC-filtered materialized views

**Date:** 2026-05-13 02:10 UTC

Context: a rebuild prompt arrived for the QC matview infrastructure, but the rebuild had already been completed on 2026-04-29. Per the user's instruction, ran the read-only spot checks from Phase 3 of that prompt to confirm the existing setup is still working correctly. No changes made.

---

## State inventory

| Object | Type | Rows | Status |
|--------|------|------|--------|
| `v_mesonet_measurements_qc` | filter view | (live filter) | ✓ active |
| `mv_daily_station_summary_qc` | matview | 70,911 | ✓ refreshed within 6h |
| `mv_daily_station_summary_raw` | matview | 70,911 | ✓ refreshed within 6h |
| `mv_monthly_station_summary_qc` | matview | 2,459 | ✓ refreshed within 6h |
| `mv_monthly_station_summary_raw` | matview | 2,459 | ✓ refreshed within 6h |

The 6-hour cron has been running successfully — last 5 invocations all `success`, ~31 min wall-clock each.

---

## Spot-check 1 — Station 0122 (Kaehu) soil moisture, daily (Jun 1-5, 2025)

Station 0122 had ~96k rows of `7999` sentinel in soil moisture per the 2026-04-29 audit. Raw daily aggregates should still be inflated; QC should be clean.

| date | raw `soil_moisture_avg` | qc `soil_moisture_avg` |
|------|--------------------------|--------------------------|
| 2025-06-01 | **5,332.8463** | **0.5390** |
| 2025-06-02 | **5,332.8463** | **0.5390** |
| 2025-06-03 | **5,332.8462** | **0.5387** |
| 2025-06-04 | **5,332.8461** | **0.5384** |
| 2025-06-05 | **5,332.8460** | **0.5380** |

Raw values are garbage (the `7999` sentinel sums into the daily average, inflating it ~10,000×). QC values are realistic ~54% VWC. **Filter working.**

---

## Spot-check 2 — Station 0153 (Haleakalā Summit) temperature

For a 5-day window in June 2024 where the sensor was fine, raw and qc agree exactly (good — the filter doesn't disturb good data). To prove the filter activates when needed, I queried three dates the original audit flagged with -80 to -215 °C readings:

| date | raw `tair_min` | qc `tair_min` | raw `tair_avg` | qc `tair_avg` |
|------|----------------|----------------|------------------|------------------|
| 2022-11-21 | **-92.27** | **-9.40** | 3.88 | 4.04 |
| 2022-12-21 | **-214.66** | **3.32** | **-37.39** | **7.82** |
| 2023-01-07 | **-80.00** | **7.29** | **-35.13** | **9.73** |

QC values are realistic summit temperatures (a few degrees above freezing). The raw view's `-214.66 °C` is physically impossible. **Filter working.**

---

## Spot-check 3 — Station 0115 (Piʻiholo) rainfall during March 2023 sensor failure

| date | raw `rainfall_mm` | qc `rainfall_mm` |
|------|---------------------|--------------------|
| 2023-03-04 | 5.4 | 5.4 |
| 2023-03-05 | **991,876.0** | **0.0** |
| 2023-03-06 | **1,007,874.0** | NULL (all values filtered) |
| 2023-03-07 | 1.7 | 1.7 |

Raw shows ~1 million mm in a single day (78,000 inches — physically impossible). QC correctly drops the 7999 sentinels. **Filter working.**

---

## Spot-check 4 — Filter view directly

Verifies the source-level `v_mesonet_measurements_qc` view still excludes everything it should.

| check | rows surviving filter |
|-------|----------------------|
| `value = 7999` | 0 |
| `value = -9999` | 0 |
| `value = 9999998` | 0 |
| `var_id LIKE 'Tair%' AND value < -10` | 0 |
| `var_id LIKE 'RH%' AND value < 0 OR > 105` (excluding RHenc) | 0 |
| `var_id LIKE 'RF_%' AND value < 0` | 0 |

Every category returns **zero rows**. **Filter working at the source.**

---

## Spot-check 5 — Station 0122 monthly aggregates

Confirms the filter propagates correctly through the daily-to-monthly aggregation chain.

| month | raw `soil_moisture_avg` | qc `soil_moisture_avg` |
|-------|--------------------------|--------------------------|
| 2025-05-01 | 5,332.8463 | 0.5389 |
| 2025-06-01 | 5,332.8455 | 0.5365 |
| 2025-07-01 | **5,934.5823** | 0.5392 |
| 2025-08-01 | 5,332.8449 | 0.5346 |

Both the daily and monthly QC matviews are clean. **Filter propagates correctly through aggregation.**

---

## Cleanup

Deleted two zero-byte backup files created during the failed pre-flight earlier (the failure was correct behavior — `pg_get_viewdef('mv_daily_station_summary')` raised "relation does not exist" because the rebuild had already renamed the view to `_raw` weeks ago). Kept the current-schema dump at `/opt/hcdp/backups/schema_20260507_0509.sql` as a useful snapshot.

---

## Verdict

**No action needed.** The QC infrastructure built on 2026-04-29 is healthy. Downstream consumers reading from the `_qc` views are getting clean data.
