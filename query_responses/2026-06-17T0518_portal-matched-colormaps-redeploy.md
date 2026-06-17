# Query: Re-pull 2 files from qgis-glue for portal-matched default colormaps

**Date:** 2026-06-17 05:18 UTC
**Scope:** pulled 2 files from `qgis-glue` into the deployment checkout to pick up
portal-matched default colormaps (RH/NDVI/SPI/temperature → viridis-family). Branch stayed
`claude/integrate-pipeline-codex-OMPo2`. No service restart (MCP server is spawned fresh per
session → next conversation picks them up). Did not touch raster service, qgis-mcp, Postgres,
firewall, or VNC.

---

## Files updated (timestamped `.bak` backups made)

```
chatbot/raster_spec.py
jetstream2/agent_reference/raster_recipes.md
```

Backups: `<file>.20260617T051759Z.bak`. Brought in via
`git checkout origin/qgis-glue -- <paths>`; deployment branch not switched.

## Resolved qgis-glue commit

```
0c00c7a  Match all datatype colormaps to the HCDP portal (confirmed from the viewer)
```

## Sanity check

`python3 -m py_compile chatbot/raster_spec.py` → **exit 0** (loads clean).

## Default colormaps (the five lines)

```
temp     -> viridis
rh       -> viridis_r
ndvi     -> viridis_r
spi      -> viridis_r
ignition -> viridis
```

Matches the expected portal-matched defaults exactly (viridis / viridis_r / viridis_r /
viridis_r / viridis).

## Result

Both files deployed and load clean; default colormaps now match the HCDP portal viewer. No
restart performed (not needed for the MCP server). Nothing else touched.
