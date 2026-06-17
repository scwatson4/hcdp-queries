# Query: Re-deploy updated HCDP raster/QGIS files from qgis-glue + verify

**Date:** 2026-06-17 04:21 UTC
**Scope:** pulled 5 changed files from `qgis-glue` into the deployment checkout, restarted
the raster service, verified the new staging route + datatype resolution. Branch stayed
`claude/integrate-pipeline-codex-OMPo2`. Did not touch firewall, VNC, Postgres, or qgis-mcp.

---

## Files updated (all 5 changed; timestamped `.bak` backups made)

```
tools/hcdp_raster_mcp_server.py
chatbot/raster_spec.py
chatbot/hcdp_raster_client.py
services/jetstream2/raster_service/routes.py   (symlinked → live /opt/hcdp/raster_service/routes.py)
jetstream2/agent_reference/raster_recipes.md
```

Brought in via `git checkout origin/qgis-glue -- <paths>` (qgis-glue now at `3a50db2`); the
deployment branch was not switched. Backups: `<file>.20260617T042048Z.bak`.

## Compile sanity-check

`python3 -m py_compile` on the 4 Python files → **exit 0** (all load clean). The X-Island
latin-1 header fix (`_ascii_header`) is preserved in the new routes.py.

## Raster service restart

- `sudo systemctl restart hcdp-raster-service` → `is-active: active`
- `GET /health` → **HTTP 200** `{"status":"ok","service":"hcdp-raster-service","version":"0.1"}`
- New route registered: `/raster/file` without an API key → **HTTP 401** (auth required, not 404).

## `/raster/file` smoke test (new staging route)

Key sourced from the raster-service env (not printed):

```json
{"path":"/media/volume/hcdp_rasters/rainfall_new_month_2024-03_statewide.tif",
 "product":"rainfall_new_month","date":"2024-03","extent":"statewide","bytes":1803400}
```

Returns a real local `.tif` (1.8 MB) on the shared filesystem — proves the
`stage_climate_grids` backend (download-to-disk + return path) works. This is the primitive
behind multi-month aggregation (annual totals, decadal differences) that the per-month
spec/overlay endpoints don't cover.

## `build_raster_spec` resolves the new datatypes

```python
from raster_spec import build_raster_spec as b
b('ignition_probability', ['latest'])['colormap']   # -> ylorrd
b('spi', ['2024-06'], timescale=12)['vmin']         # -> -3.0
```

→ exactly as expected: `ylorrd` (fire-risk ramp) and `-3.0` (SPI fixed diverging domain).

## Result

All 5 files deployed and load clean; raster service restarted and healthy with the new
`GET /raster/file` route live; new datatypes (ignition_probability, spi) resolve in the
MCP spec builder. Nothing failed to load.

The MCP servers were **not** restarted — the CLI spawns them fresh per session, so they pick
up the new tools on the next conversation. Not touched: firewall, VNC, Postgres, qgis-mcp.
