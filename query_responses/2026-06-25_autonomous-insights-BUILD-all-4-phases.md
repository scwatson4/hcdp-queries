# Autonomous climate insights — all 4 phases built and running

**Date:** 2026-06-25
**Scope:** built the full 4-phase autonomous-insights system from the roadmap, on the live stack.
Everything is **additive and reversible** — a new `derived_insights` Postgres schema, a new
`/opt/hcdp/insights/` code tree, and two new cron lines. No existing data, deployed code, or config
was modified. No secrets printed.

---

## What now exists

### Phase 1 — `derived_insights` foundation (DB schema + computed metrics)
Recomputed from the 36-year `historical_station_values` + mesonet data:

| table | rows | what it is |
|---|---|---|
| `di_station_spi` | 248,834 | SPI (normal-approx) at 3- & 12-month scales per station/month, with USDM drought category |
| `di_rainfall_anomaly` | 131,193 | monthly rainfall vs the station's own 1991–2010 normal (% of normal, anomaly mm) |
| `di_rainfall_trend` | 326 | per-station annual-rainfall linear trend (slope mm/yr, %/yr, R²) over ≥20 yrs |
| `di_soil_moisture_pctile` | 72 | current mesonet soil moisture vs each station's own history (percentile) |
| `di_refresh_log` | persistent | run bookkeeping |

**Verified:** current SPI-12 shows **125 of 514 stations (24%) in drought** (3 Exceptional / 11
Extreme / 11 Severe / 51 Moderate / 49 D0); credible multi-decade drying trends (up to −2.9%/yr);
driest soil at Kīpuka Nui (4th percentile).

### Phase 2 — composite indices (per island, 0–100)
`di_island_conditions`, `di_fire_risk_island`, `di_drought_island` — transparent weighted blends of
mesonet fire-weather (VPD, RH, wind, temp) and soil/rain deficits.

**Verified (2026-06-24):** Molokaʻi highest — fire **28 (Low)**, drought **51 (Moderate)** — driven
by the lowest 30-day rain (45.6 mm) and highest wind/VPD; Hawaiʻi lowest. Fire class is "Low"
statewide — correct and non-alarming for humid late-June, while still ranking the dry leeward
islands first.

### Phase 3 — autonomous "Climate Watch" (generator + Sankey + weekly publish)
- `bin/climate_watch.py` → a markdown report (statewide drought snapshot, island risk table, soil
  extremes, drying trends, drought-category transitions) **plus a Sankey JSON** of SPI-12 category
  flows (12 months ago → now). Deterministic — no API/agent cost.
- `bin/publish_climate_watch.sh` → runs the generator, leak-scans, commits & pushes to `hcdp-queries`.
- **Sample output committed alongside this report:** `2026-06-24_climate-watch.md` +
  `2026-06-24_climate-watch-sankey.json`. The Sankey shows a net drying signal (121 stations
  Wet→Normal, 27 Wet→D0 over the year). Render with the `render_chart` MCP (`chart_type: sankey`).

### Phase 4 — on-demand area analysis
- `bin/analyze_area.py "<Island>"` → a focused drought + fire-risk report for any island (verdict,
  current conditions, component scores, driest-soil stations).
- **Sample committed:** `2026-06-24_area-analysis-molokai.md`.

## Autonomy — what runs on its own now
Two cron lines added (alongside the existing ingest/refresh-views jobs):
```
10 12 * * *   /opt/hcdp/insights/bin/refresh_insights.sh        # nightly 02:10 HST — recompute Phase 1+2
20 16 * * 1   /opt/hcdp/insights/bin/publish_climate_watch.sh   # weekly Mon 06:20 HST — publish report+Sankey
```
The refresh is light (no billion-row scan — seconds). **The weekly job auto-publishes to GitHub** —
to pause it, remove that crontab line (`crontab -e`).

## Methodology & honest caveats (important)
- **The indices are v1 heuristics** with transparent, hand-set weights — they rank/triage correctly
  but the absolute 0–100 values are **not yet calibrated** against historical fire/drought outcomes.
  Calibration + validation against known events is the next step before operational use.
- **SPI is a normal-approximation** (z-score of trailing-N-month precip), not a gamma-fit SPI — a
  defensible v1; a gamma fit is a future refinement.
- **"Outlook/risk," not a forecast.** No physical/GCM model on-box; all forward-looking content is
  statistical. (The deployed forecast-disclaimer doc rule applies.)
- **Network split:** SPI/trends come from the *historical* network (SKN IDs, **no island column**),
  so they're surfaced station-level; the island composite indices are *mesonet*-based. Mapping SKN
  stations to islands (via coordinates) would let drought roll up by island — a clear next improvement.
- **Data-quality guards still matter at scale** (completeness, stuck-zero gauges, % of normal) — the
  Phase 1 queries use QC views and the historical record; extend the driest-station guards as these
  feed alerts.

## Reversibility
- Drop the schema: `DROP SCHEMA derived_insights CASCADE;`
- Remove the code: `rm -rf /opt/hcdp/insights`
- Remove the two crontab lines.
Nothing else is touched.

## Suggested next steps (productionization)
1. **Calibrate & validate** the fire/drought indices against historical events; add confidence.
2. **SKN→island mapping** so SPI/trends roll up to island composites.
3. **Add the NDVI + `ignition_probability` grids** (already in the raster pipeline) to the fire index
   via QGIS zonal stats.
4. **Promote the code to the repo** (`hcdp-ai-interface@qgis-glue`) so it's version-controlled and
   reviewable, like the rest of the stack.
5. **Agent-narrated variant** of the weekly report (headless `claude -p`) for richer prose +
   threshold alerting; and an "analyze area X" MCP/workflow surface for the chatbot.

## Provenance
Code: `/opt/hcdp/insights/{sql,bin}`. Data: `derived_insights.*` computed from
`historical_station_values` (1990–2026), `v_mesonet_measurements_qc`, `mv_daily_station_summary_qc`,
`mesonet_stations`. Cron: exouser crontab. All build steps run and verified this session.
