# Why the reference docs let the chatbot get "driest station" wrong — agent-file gap analysis

**Date:** 2026-06-24
**Scope:** read-only analysis of the agent-facing files under `jetstream2/` that Claude-mode and
Codex-mode read at query time, diagnosing why an out-of-band session (this one) produced correct
"driest station" answers while the in-product Claude CLI mode, reading these same files, did not.
No code/service/data changes. No secrets in this document.

---

## Where the agent files live (direct answer)

Two copies, and the distinction matters:

- **Source of truth (what you edit):** the `hcdp-ai-interface` repo, `qgis-glue` branch, `jetstream2/`
  folder — `CLAUDE.md`, `AGENTS.md`, and `agent_reference/*.md` (schema, query_patterns,
  data_quality, methodology, data_products, stations, variables, geography, connection,
  raster_recipes, response_style).
  → https://github.com/scwatson4/hcdp-ai-interface/tree/qgis-glue/jetstream2
- **What the CLIs actually read at runtime:** a deployed checkout on the Jetstream2 instance at
  `/opt/hcdp/src/jetstream2/`. The backend `cd`s there before running `claude -p` / `codex exec`.
  Edits to the repo don't take effect until a redeploy (`git checkout origin/qgis-glue -- …`).

This analysis read the runtime copy at `/opt/hcdp/src/jetstream2/` (identical to `qgis-glue`).

---

## Bottom line

The docs are genuinely good at one class of error and **structurally blind to another**. Their QC
philosophy is **asymmetric — it only defends against values that are too HIGH** (sentinel codes,
tipping-bucket spikes, physical maxima). Every technique that produced correct "driest" answers in
this session defends against the **LOW side and against context** — and **none of it is in the
docs**. The chatbot wasn't reasoning worse; the docs channel it into a recipe that is blind to the
dominant failure mode for dry-station queries, and then explicitly reassure it that the recipe is
safe.

## Evidence: concept presence across all 11 `agent_reference/*.md` files

| Concept (the techniques that fixed the answers) | Files mentioning it |
|---|---|
| Completeness guard (partial month / reporting-days / `days_rep`) | **0** |
| Under-reporting / stuck-at-zero / clogged / failed gauge / near-zero | **0** |
| "% of normal" / "vs normal" as a numeric cross-check | **0** |
| `climatology_rasters` (the normals table you can sample) | **0** |
| `rainfall_climatology` grids | 2 — **map display only** (raster_recipes, response_style) |
| "normal" (any sense) | 3 — storm-excess (methodology), vocab (response_style), maps (raster_recipes) |
| `historical_station_values` (portal's 1990+ network) | 6 — but positioned for *trends/events*, not "where is the driest" |

The corrective tools either don't exist in the docs (completeness, under-report, %-of-normal,
`climatology_rasters`) or exist **only in the map-rendering context**, never wired into the
SQL/analysis path that answers a "driest stations" question.

## The three specific places the docs steer wrong

1. **`query_patterns.md` → "Station ranking (wettest/driest)"** is the recipe the chatbot used. It
   ranks raw `AVG(rainfall_mm)` from `mv_daily_station_summary_qc` with only `HAVING COUNT(*) > 365`.
   It has **no per-period completeness guard, no under-report guard, no normal cross-check**, and it
   closes with the falsely-reassuring line:
   > *"No station exclusions needed — `mv_daily_station_summary_qc` already handles sentinel
   > contamination."*
   That sentence is true for sentinels and false for the failure mode that actually matters here. A
   clogged bucket reporting `0.0` is not NULL, not 7999, not a spike, and is within physical range —
   so it sails through every `_qc` filter and lands at the **top of a driest ranking**.

2. **`methodology.md` → Pitfall 6: "Wettest/driest station rankings are contaminated"** addresses
   **only the high side** (station 0115's 7999 codes inflating the *wettest*). The mirror-image
   problem — under-reporting/failed gauges contaminating the *driest* — is never stated, even though
   the section's title implies both directions.

3. **`methodology.md` → Pitfall 1 ("network composition bias")** explicitly tells the agent that
   *"Mesonet-only analysis within a period where station count was stable (2025–2026)"* needs **no**
   special handling. For "driest stations May 2026" that reads as a green light to rank the sparse
   2022+ mesonet with no normal cross-check — exactly the path that failed.

## What the docs do well (so the fix is additive, not a rewrite)

- The 7999 sentinel rule, the 0602 spike pattern, and physical-plausibility thresholds
  (`data_quality.md`) are correct and valuable.
- The reference-panel method for cross-year bias (`methodology.md` Pitfall 1) is genuinely
  sophisticated and correct.
- HST/UTC handling, elevation/lapse-rate station selection, and the ASCII-vs-ʻokina island-name trap
  (`query_patterns.md`) are real, hard-won guidance.
- Both networks are documented in `data_products.md` (mesonet 78 active vs historical 564/~270) — the
  agent *knows they exist*; what's missing is the instruction to **use the historical/gridded normal
  to validate a mesonet ranking.**

## Why this session got it right (the behavioral delta)

The corrective steps weren't doc-driven — they came from cross-checking the live system against
domain knowledge:

1. **Cross-checked every "driest" candidate against the 1991–2010 climatology** by sampling
   `rainfall_climatology_1991_2010_month05.tif` (registered in `climatology_rasters`) with rasterio —
   a numeric `% of normal`, not a map. This is what exposed Waipā (0.8 mm vs a 121.8 mm north-shore
   normal = 1% → failed gauge) and separated March 2026's "driest" list as a wet-month/gauge-failure
   artifact rather than aridity.
2. **Added a ≥28-day completeness guard** to kill partial-month undercounts (Kaʻehu's 4-day May,
   Manukā's 10-day May).
3. **Applied domain skepticism to zeros** — a wet-climate north-shore gauge reading ~0 is a sensor
   failure, not a record; an exact 0.0 for two consecutive months (Haleakalā Summit) is flagged, not
   reported.
4. **Stayed aware of the network/units mismatch** (mesonet vs portal's 622-gauge grid; mm vs inches)
   throughout.

The chatbot, following the docs literally, had no instruction to do any of (1)–(4) — and
`query_patterns.md` told it the `_qc` view already "handles" contamination, so it had positive
reason **not** to.

## Recommended additions to the agent docs (targeted patches)

1. **`data_quality.md` — add a "low-side / under-report" rule.** State plainly that the `_qc` views do
   NOT catch a gauge stuck at/near zero (clogged tipping bucket, failed sensor), because such values
   pass every existing filter. Give the signature: a wet-climate station reading far below its
   climatological normal, full-month exact-zeros, or ≥2 consecutive near-zero months. Add Waipā,
   Lower Limahuli, Common Ground (Kauaʻi north-shore) to the known-bad inventory as **under-reporters**
   (0602/Common Ground is currently listed only as a *spike* station — it under-reports too).
2. **`query_patterns.md` — fix the driest/wettest recipe.** Add (a) a per-period completeness guard
   (`days_rep >= 28` for monthly, from the daily MV), (b) a `% of normal` column sampled from the
   climatology, and (c) delete/qualify the "no exclusions needed" reassurance. Show genuine aridity,
   seasonality, and gauge failure as **separate** outputs, not one ranked list.
3. **`methodology.md` — make Pitfall 6 two-directional** ("driest" contamination from under-reporters,
   not just "wettest" from sentinels) and add a checklist item: *"If ranking driest/lowest, did I
   compare each candidate to its climatological normal and flag wet-climate gauges reading far below
   it?"*
4. **Document `climatology_rasters` + the `/climatology/sample` path** in `data_products.md` /
   `schema.md` as a **numeric** tool (sample the 1991–2010 monthly normal at a lat/lng), not just the
   map overlay it's currently presented as in `raster_recipes.md`. This is the single highest-leverage
   addition: it turns "% of normal" from a thing the model has to invent into a documented step.
5. **Add network-selection guidance:** current-month/recent → mesonet `_qc` views; historical or
   portal-matching → `historical_station_values`; and **always** cross-check a "driest" claim against
   the gridded normal. State that the mesonet is sparse/recent and not the portal's network.
6. **Backfill station metadata:** Manukā / Keōpukaloa show `island = 'Unknown'` despite valid
   coordinates — fix in `mesonet_stations` (and note in `stations.md`).

## Provenance
Files read from `/opt/hcdp/src/jetstream2/` (runtime copy of `hcdp-ai-interface@qgis-glue`).
Concept-presence counts from `grep -rilE` over `agent_reference/*.md`. Live-data cross-checks from
prior reports this session (mesonet `_qc` views + `rainfall_climatology_1991_2010_month0{3,5}.tif`).
Read-only.
