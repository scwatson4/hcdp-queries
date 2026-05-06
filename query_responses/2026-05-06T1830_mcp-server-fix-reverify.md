# Query: Pull the MCP tool-schema fix and re-verify

**Date:** 2026-05-06 18:30 UTC
**Branch:** `claude/skip-pipeline-claude-mode-mZwRB`
**Fix:** commit `b4ea710` — adds `@functools.wraps` to `_wrap()` in `tools/hcdp_raster_mcp_server.py` so FastMCP introspects each tool's real signature instead of `(*args, **kwargs)`.

No re-registration needed: `/opt/hcdp/mcp/hcdp_raster_mcp_server.py` is symlinked into `/opt/hcdp/src/tools/`, so `git pull` swaps in the new code, and `claude -p` spawns a fresh MCP subprocess per invocation.

---

## Results

| Item | Result |
|------|--------|
| **HEAD short SHA after pull** | `b4ea710` ("Fix MCP tool schema: preserve tool signatures via functools.wraps") |
| **`readlink` of symlink** | `/opt/hcdp/src/tools/hcdp_raster_mcp_server.py` (target exists ✓) |

## Step 3 — signature listing (6 lines)

```
list_climate_products []
sample_climate_at_point ['product', 'lat', 'lng', 'date']
get_island_climate_stats ['product', 'island', 'date']
compute_island_anomaly ['product', 'date', 'island']
compare_grid_to_stations ['product', 'island', 'date']
show_climate_overlay_on_map ['product', 'island', 'date', 'anomaly']
```

All 6 match the expected output exactly. **No `['args', 'kwargs']` anywhere — the `functools.wraps` fix took.**

## Step 4 — last 30 lines (list_climate_products via `claude -p`)

```
The hcdp-raster MCP exposes **21 climate products** (all at 250 m spatial resolution, GeoTIFF output). Grouped:

### Rainfall (mm)
- **rainfall_legacy_month** — Giambelluca-era monthly totals, 1920-01 → 2012-12
- **rainfall_new_month** — contemporary monthly totals, 1990-01 → present (~1-2 mo lag)
- **rainfall_new_day** — daily totals, 1990-01-01 → present

### SPI — Standardized Precipitation Index (z-score)
- **spi_03_month** — 3-month timescale
- **spi_12_month** — 12-month timescale

### Temperature (°C, ~2014 → present)
- **temperature_min_month**
- **temperature_mean_month**
- **temperature_max_month**

### Rainfall climatology (1991–2010 baseline, derived from `rainfall_legacy_month`)
- **rainfall_climatology_1991_2010_annual**
- **rainfall_climatology_1991_2010_month01** … **month12** (one per calendar month)

Let me know if you'd like to sample any of these at a point, generate a map overlay, or compute anomalies.
```

## Step 5 — last 30 lines (sample at Lyon Arboretum, real params)

Prompt:

```
Use the hcdp-raster sample_climate_at_point tool to look up
rainfall_climatology_1991_2010_annual at lat=21.3331, lng=-157.8025
(Lyon Arboretum, Oahu). Just report the value and units.
```

Reply:

```
3716.83 mm
```

Single-line response. Value matches the laptop run (3716.83 mm) exactly and sits in the expected 3000–5000 mm/yr range.

## Deviations from expectations

**One** — minor and didn't affect the outcome. The introspection one-liner in step 3 used `m.mcp.tools.items()` as written, but FastMCP's public attribute is `_tool_manager._tools` in this version (3.2.4). The error was:

```
AttributeError: 'FastMCP' object has no attribute 'tools'. Did you mean: 'tool'?
```

I ran an exploratory `dir(m.mcp)` to find the right attribute (`_tool_manager._tools`), then re-ran with that. Output then matched the expected six lines exactly. This is a `fastmcp`-version surface quirk, not a deploy problem.

## Constraint compliance

- No `git commit` / `git push` from this host ✓
- `<key>` not printed ✓
- Stopped on the introspection `AttributeError`, diagnosed the API shape, and resumed with a one-line attribute fix that matched the original intent — flagged in deviations ✓
