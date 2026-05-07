# Golden Queries — HCDP MCP Integration

A reference set of climate-researcher-style prompts for end-to-end testing of the HCDP MCP servers (`hcdp-raster` + `hcdp-charts`) registered for `claude -p` on the Jetstream2 host. Each query is phrased the way a working scientist would actually ask it, and is annotated with the tools the chatbot should invoke and the result we expect to see.

These are useful for:

- Smoke-testing the MCP setup after a deploy
- Validating tool selection and parameter handling
- Catching regressions in colormap selection, multi-call orchestration, and chart-type picking
- Demonstrating end-to-end flows to other researchers / reviewers

---

## 1. Rain-shadow quantification (Big Island)

> **Quantify the rain shadow on the Big Island. Sample the long-term annual rainfall climatology at Hilo (19.71, -155.09) and at Waikoloa Village (19.93, -155.83) and tell me the ratio. About 30 km apart but completely different climate regimes.**

**Tools:** `sample_climate_at_point` × 2 (`rainfall_climatology_1991_2010_annual`).
**Expected:** Hilo ~3200 mm/yr, Waikoloa ~250 mm/yr, ratio ≈ 12–14×. Classic Hawaiʻi orography illustration.

---

## 2. Drought-state map (SPI-12)

> **Show me the SPI-12 map for the end of 2023 — I want a statewide read on drought conditions going into 2024. Highlight any areas in moderate drought (SPI ≤ -1).**

**Tools:** `show_climate_overlay_on_map(product="spi_12_month", date="2023-12")`.
**Expected:** inline diverging colormap (red/blue around zero); the chatbot flags leeward Maui and Big Island as the typical drought hotspots.

---

## 3. Within-year anomaly profile (Big Island)

> **For the Big Island, compute the monthly rainfall anomaly for each month of 2024 relative to the 1991–2010 normal. Plot as a bar chart so I can see whether the year was front-loaded or back-loaded.**

**Tools:** `compute_island_anomaly` × 12 + `render_chart` (Bar Chart).
**Expected:** 12 bars, sign-coded around zero. A coherent picture of the year's hydroclimate departure.

---

## 4. Annual cycle, single island

> **Plot the monthly rainfall on Maui for 2024 as a line chart. Overlay the 1991–2010 monthly climatology as a reference line so I can see where 2024 deviated.**

**Tools:** `get_island_climate_stats` × 12 (recent year), `get_island_climate_stats` × 12 (per-month climatology products `rainfall_climatology_1991_2010_month01..12`), `render_chart` (multi-series Line Chart).
**Expected:** two-line chart, observed vs normal, dry season May–Sep dipping into the trough.

---

## 5. Gridded-product validation against mesonet

> **How well does the `rainfall_new_month` gridded product reproduce mesonet station observations on Oʻahu for 2024? Plot the per-station bias (grid − station) as a boxplot. I'm trying to decide whether to use the grid as input to a watershed water-budget model.**

**Tools:** `compare_grid_to_stations(product="rainfall_new_month", island="Oahu", date=...)` (perhaps for one representative month, or aggregated), `render_chart` (Boxplot).
**Expected:** median bias near zero, IQR few-tens of mm, outliers at orographic extremes (Mt. Kaʻala). Tells you whether the grid is fit for purpose.

---

## 6. Interannual contrast: El Niño vs neutral year

> **Compare statewide rainfall in January 2014 (strong El Niño winter) vs January 2018 (near-neutral). Show me the maps side by side and tell me which islands were affected most. ENSO impacts on Hawaiʻi rainfall are subtle and I want to see if 2014 looks notably drier.**

**Tools:** `show_climate_overlay_on_map(product="rainfall_new_month", date="2014-01")` and again for `"2018-01"`.
**Expected:** two inline overlays. The chatbot should note Kauaʻi and Oʻahu typically show stronger ENSO sensitivity than the Big Island.

---

## 7. Cross-island climatology

> **Give me a bar chart of long-term annual rainfall by Hawaiian island — Kauaʻi, Oʻahu, Maui, Hawaiʻi. I'm including this in a paper as a basic context figure.**

**Tools:** `get_island_climate_stats(product="rainfall_climatology_1991_2010_annual", island=...)` × 4 + `render_chart` (Bar Chart).
**Expected:** Kauaʻi highest (~2200 mm island-mean), Big Island lowest (largest leeward area pulls the mean down), Oʻahu and Maui in the middle.

---

## 8. Anomaly overlay for a recent season

> **Show me the rainfall anomaly map for Maui in February 2024 — was Haleakalā's windward slope close to normal that month, or was it part of a drier-than-usual pattern?**

**Tools:** `show_climate_overlay_on_map(product="rainfall_new_month", island="Maui", date="2024-02", anomaly=True)`.
**Expected:** diverging colormap centered at zero; the chatbot reads off the windward-slope sign and bounds.

---

## 9. Calibration scatter

> **Sample the 1991–2010 annual climatology at every Oʻahu mesonet station's location, then plot climatology-grid-value vs station-mean as a scatter. Points should fall near y=x if the grid is well-calibrated; deviations tell me where the grid systematically mis-represents the station.**

**Tools:** `compare_grid_to_stations(product="rainfall_climatology_1991_2010_annual", island="Oahu")` + `render_chart` (Scatter Chart).
**Expected:** tight 1:1 cluster with a few outliers (typically the orographic tops). If you see a systematic bias, the grid has issues.

---

## 10. Spatial heterogeneity check

> **Show the SPI-3 map for Kauaʻi at the end of August 2023 — short-timescale drought. I'm trying to see whether dry conditions were spatially coherent across the island or patchy. If patchy, I'll need to weight my watershed-level analysis differently.**

**Tools:** `show_climate_overlay_on_map(product="spi_03_month", island="Kauai", date="2023-08")`.
**Expected:** inline overlay; the chatbot assesses spatial coherence ("uniform across the island" vs "leeward South Shore drier than the windward Hanalei area").

---

## Notes for getting good results

- **For multi-call queries (#3, #4, #7),** the chatbot is good at parallelizing the data-fetch tools. Watch the pipeline panel — you should see ~12 `get_island_climate_stats` calls fan out before the single `render_chart` call.
- **For #5 (validation boxplot),** the chatbot has flexibility in how it aggregates: per-month for the year, or pooled over all months. Either is defensible — add "show me one boxplot per month" if you want the temporal axis broken out.
- **For #2 and #10 (SPI maps),** the colormap should be diverging (RdBu or similar). If you see a sequential blue-only map, the MCP server defaulted to the wrong colormap — that's a service-side issue, not a chatbot bug.
- **The `markLine` overlay in #4** is asking the chatbot to add a horizontal reference line in ECharts. That's a stretch — the chatbot might fall back to a plain two-series line instead. Either output is useful.
