# Autonomous climate insights on HCDP: what's feasible, how to build it, and the honest limits

**Date:** 2026-06-25
**Scope:** a grounded roadmap for richer, autonomously-run analytics on the HCDP Jetstream2 stack —
Sankey flows, long-term trend/drought outlooks, and area-level drought & fire-risk scoring — using
only the data and tools already present. Read-only survey + design. No changes made.

---

## TL;DR

All three example use-cases are feasible with what's already here. The system has a 36-year
historical record, pre-computed SPI drought grids, a rich fire-weather sensor set, a native Sankey
chart renderer, QGIS automation, and a proven cron + headless-agent pattern for autonomy. The main
honest limit: "drought/fire **prediction**" here means **statistical risk/outlook**, not a physical
forecast — there is no numerical climate model on the box. Frame outputs accordingly (and the new
forecast-disclaimer doc rule already covers this).

---

## What the stack actually gives us (verified this session)

**Data**
- `mesonet_measurements` — ~1.03 B rows, 5-min cadence, 2022→present, 104 stations. Variables include
  the full fire-weather/drought set: `RF` (rain), `Tair`, `RH`, `WS`/`WG` (wind + gust), `VPD`
  (vapor-pressure deficit), `SM`/`SM1-3` (soil moisture by depth), `Tsoil`, `SWin`/`PAR` (radiation),
  `FM` (fuel moisture), `LWS` (leaf wetness), and `Lightning`/`LightningDist` (ignition source).
- `historical_station_values` — **monthly rainfall 1990→2026 for 667 stations** (147 k rows) and
  temperature for 281. The long-term backbone for trends, SPI climatology, and normals.
- Gridded products (GeoTIFF, served by the raster service): rainfall (legacy + new, daily/monthly),
  temperature (min/mean/max), **SPI drought index at 3- and 12-month timescales** (`spi_03_month`,
  `spi_12_month`), 1991–2010 climatology normals, and rainfall **anomaly** grids. The spec pipeline
  (`raster_spec.py`) also handles NDVI and `ignition_probability` (fire-risk) products.
- `mv_daily/monthly_station_summary_qc` (pre-aggregated), `climatology_rasters` (numeric normals),
  `mesonet_stations` + `hawaii_islands` (PostGIS polygons), `station_monitor` (latest snapshot).

**Tools**
- PostgreSQL + PostGIS (spatial + temporal SQL), now on a 535-GB-headroom volume.
- HCDP raster service (FastAPI): climatology point-sampling, anomaly stats, derived-raster/animation
  publishing, island masking, overlays.
- MCP servers: `hcdp-raster` (anomaly, island stats, point sample, grid-vs-station compare, stage
  grids, publish derived raster/animation, map overlays), `hcdp-charts` (**bar/line/scatter/pie/
  heatmap/sankey**), `hcdp-tables`, and full `qgis` automation (zonal statistics, raster calculator,
  processing models, atlas/layout map production).
- Autonomy primitives already proven on this box: `cron` (15-min ingest, 6-hourly MV refresh) and
  headless agent runs (`claude -p` / `codex exec`) with the `agent_reference` rulebook.
- Publication pipeline: the public `hcdp-queries` repo (these reports).

---

## Use-case 1 — Sankey diagrams (natively renderable)

`render_chart` already supports `sankey`, so this is wiring data, not building infra. High-value flows:

- **Drought-category transition flow.** Bucket each station's SPI into D-categories (Normal, D0–D4)
  and Sankey the month-over-month movement — how many stations flowed Normal→Moderate→Severe. A
  genuinely informative "drought is spreading/easing" visual. Source: SPI grids sampled at stations,
  or station-level SPI from the historical record.
- **Rainfall budget flow.** Total rainfall → island → windward/leeward region → station, for a chosen
  month/season. Source: `mv_monthly_station_summary_qc` + `hawaii_islands` + an aspect/region split.
- **Station-network lifecycle.** planned → active → inactive over time (the `status` field we just
  ingested), showing network growth/attrition.

## Use-case 2 — Long-term trends & drought outlook (strong fit; be honest about "prediction")

The 36-year monthly record is the asset. Concrete, defensible analyses:

- **Trend detection.** Per station/island/region: linear regression + Mann-Kendall (non-parametric)
  on annual and seasonal rainfall → flag significant drying/wetting trends with confidence. Sen's
  slope for magnitude.
- **SPI climatology & drought history.** Compute/track SPI at 1/3/6/12-month scales; derive drought
  onset, duration, severity, and return periods per region — a real drought atlas from local data.
- **Statistical drought outlook (NOT a physics forecast).** Combine current multi-scale SPI +
  antecedent soil-moisture percentile + seasonal climatology + persistence to estimate the
  *probability* of continued/worsening drought over the next 1–3 months. This is nowcasting +
  statistical outlook — label it as such (the deployed forecast-disclaimer rule applies).
- **Optional external lift:** Hawaiʻi drought is strongly ENSO-driven; an autonomous backend job
  (not the web-restricted chatbot persona) could pull a NOAA CPC ENSO/seasonal-outlook feed to
  condition the outlook. Flagged as an enhancement, not a dependency.

## Use-case 3 — Area-level drought & fire-risk scoring (strong fit; rich inputs)

- **Drought risk for an area:** multi-timescale SPI + rainfall % of 1991–2010 normal (already
  demonstrated via `climatology_rasters`) + soil-moisture percentile vs the station's own history,
  aggregated over an island/region polygon with QGIS `zonal_statistics`.
- **Composite fire-risk index:** combine the fire-weather variables we actually have —
  VPD (high = dry air), RH (low), wind gust (`WG`), temperature, soil & fuel moisture (`SM`, `FM`),
  vegetation dryness (NDVI), and the rainfall/SPI deficit — plus the `ignition_probability` grid and
  `Lightning` as an ignition trigger. Normalize each to a percentile, weight, and combine into a
  0–100 danger rating per area (a simplified NFDRS/Keetch-Byram-style index). QGIS `raster_calculator`
  + `zonal_statistics` handle the gridded combination; SQL handles the station-based parts.
- Validate against known historical fire/drought events before any operational use.

---

## How to make it autonomous (architecture)

A four-layer design that mirrors the existing ingest pattern:

1. **Derived-metrics layer (scheduled cron jobs).** Nightly/weekly jobs compute and **persist** SPI
   rollups, rainfall anomalies, soil-moisture percentiles, trend slopes, and the composite drought/
   fire indices into a new `derived_insights` schema (tables or MVs). Feasible now with 535 GB free.
   Reuse `ingest.py`'s discipline (`work_mem` tuning, off-peak scheduling, idempotent upserts).
2. **Analysis-agent layer (cron-invoked headless agent).** A scheduled `claude -p` / `codex exec`
   run — the same infra the chatbot uses — reads the derived metrics, detects emerging risk, and
   writes a narrative report plus visuals (maps via the raster service/QGIS, charts & Sankey via the
   chart MCP). This is where "autonomous insights" actually happen.
3. **Publication layer (exists).** Push reports + visuals to `hcdp-queries` (or a dashboard).
4. **Alerting layer.** Threshold triggers (e.g. SPI < −1.5, fire index > 80, soil-moisture < 5th
   percentile) raise a flagged report / notification.

**On-demand variant:** for deep one-off analyses ("assess drought+fire risk for leeward Maui"),
fan out a multi-agent **workflow** (per-region / per-timescale / per-hazard agents → adversarial
verify → synthesize) rather than a single pass.

**Scheduling primitives:** `cron` (proven here) for the recurring jobs; the agent runtime's
scheduling tools for self-paced loops; the Workflow engine for comprehensive on-demand fan-out.

---

## Honest limits & guardrails (so this doesn't produce confident nonsense at scale)

- **No physical forecast model on-box.** "Prediction" = statistical risk/outlook. Always disclaim
  (the new forecast rule). Don't imply GCM-grade certainty.
- **Short mesonet record (2022+).** Use the 36-yr historical for climatology/trends; use the mesonet
  for current conditions and fire-weather. Don't compute "normals" from 2–4 mesonet years.
- **Bake in the data-quality guards from the driest-station saga.** Completeness (`days_reporting`),
  stuck-at-zero/under-reporting gauges, and `% of normal` cross-checks must be automated into every
  job — at autonomous scale, a clogged gauge becomes a false "extreme drought" alert.
- **Spatial sparseness + interpolation uncertainty.** 104 mesonet / 667 historical stations; gridded
  products fill gaps but carry interpolation error — report uncertainty, especially in data-sparse
  leeward/summit zones.
- **Validate indices against known events** before operational alerting.
- **Compute cost is real.** A full SPI/MV rebuild is heavy (the daily MV refresh took ~14 min over a
  billion rows). Persist results, tune `work_mem`, schedule off-peak, refresh incrementally where
  possible.
- **Network/security:** autonomous external feeds (ENSO) belong in a backend job, not the
  web-restricted chatbot persona; keep secrets out of logs/reports (the standing rule).

---

## Suggested phased build

1. **Phase 1 — derived-metrics foundation.** `derived_insights` schema + nightly cron: SPI rollups,
   anomalies, soil-moisture percentiles, trend stats. (Highest leverage; everything else builds on it.)
2. **Phase 2 — composite indices.** Per-island/region drought and fire-risk scores (zonal), validated
   against history.
3. **Phase 3 — autonomous "climate watch".** Weekly headless-agent run → narrative report + Sankey +
   maps published to `hcdp-queries`; threshold alerting.
4. **Phase 4 — on-demand deep analysis.** An "analyze area X" workflow (multi-agent fan-out) for
   ad-hoc risk assessments.

Each phase is independently useful and ships a visible artifact. Phase 1 alone turns the raw
billion-row firehose into queryable, trend-ready metrics; the later phases layer interpretation and
autonomy on top.

## Provenance
Inventory verified read-only this session: `/media/volume/hcdp_rasters` (product list incl. SPI 3/12-
month + anomaly + climatology), `historical_station_values` (1990→2026, 667 rainfall stations),
`mesonet_variables` (fire-weather sensor set), `chart_mcp_server.py` (`sankey` supported), plus the
raster service, QGIS MCP, cron, and headless-agent infra observed throughout this session.
