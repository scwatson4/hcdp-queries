# Query: QGIS install + regression gate — Phase 1b–1e

**Date:** 2026-06-15 00:50 UTC
**Mode:** actual install of QGIS, then live before/after regression proof on the production services. Hard stop at end of Phase 1e (no Phase 2).

---

## Disk gate (precondition)

```
/dev/sda1  58G total  16G used  41.1G avail  28%  /
```

41.1 GB free on `/` — far above the ≥3 GB requirement. PASS.

## Phase 1b — install

```
sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l apt-get install -y qgis python3-qgis
exit code: 0
```

- 157 packages installed, **0 upgraded** — matched the Phase 1a dry-run exactly.
- `NEEDRESTART_MODE=l` (list-only): needrestart **deferred** all service restarts instead of executing them. The deferred list was dbus / docker / networkd-dispatcher / systemd-logind / unattended-upgrades — none of which it actually restarted. Critically, **neither `hcdp-raster-service`, Postgres, nor docker was bounced**, so the Guacamole web-desktop stack and the raster service stayed up throughout.

## Phase 1c/1d — QGIS works

```
$ QT_QPA_PLATFORM=offscreen qgis --version
QGIS 3.44.7-Solothurn 'Solothurn' (ea262bc5ed8)          exit 0

$ dpkg -s qgis | grep ^Version
Version: 1:3.44.7+40noble

$ QT_QPA_PLATFORM=offscreen python3 -c "from qgis.core import Qgis; print(Qgis.version(), Qgis.versionInt())"
import qgis.core: OK
Qgis.version():    3.44.7-Solothurn
Qgis.versionInt(): 34407
```

`qgis.core` imports from the **system** python3 (where QGIS lives in dist-packages) — this is correct and separate from the service venvs.

## Phase 1e — regression gate (live before/after, the real test)

| Check | BEFORE install | AFTER install | Verdict |
|---|---|---|---|
| `hcdp-raster-service` unit | active | active | unchanged |
| raster `/health` | 200 `{"status":"ok",...}` | 200 `{"status":"ok",...}` | unchanged |
| Postgres | (baseline not taken) | up, `127.0.0.1:5432 - accepting connections`, query OK | healthy |
| `hcdp_raster_mcp_server` | 7 tools | 7 tools, same names | unchanged |
| `chart_mcp_server` | 1 (`render_chart`) | 1 (`render_chart`) | unchanged |
| `table_mcp_server` | 1 (`render_table`) | 1 (`render_table`) | unchanged |
| service venv rasterio | GDAL 3.12.1 (bundled) | GDAL 3.12.1 (bundled) | unchanged |

`hcdp_raster_mcp_server` tool set (identical before and after):
```
compare_grid_to_stations
compute_island_anomaly
get_island_climate_stats
list_climate_products
sample_climate_at_point
show_climate_overlay_on_map
show_climate_raster_on_map
```

Introspection method: imported each server module with `/opt/hcdp/raster_service/.venv/bin/python3` from `/opt/hcdp/mcp/` (exactly the interpreter + path the CLI uses to launch them), then read `mcp._tool_manager._tools`.

## Discrepancy flagged (per the "live code is source of truth" directive)

The task condition referenced "three FastMCP systemd units." **No such units exist.** Only `hcdp-raster-service.service` is systemd-managed. The three MCP servers (`hcdp_raster_mcp_server`, `chart_mcp_server`, `table_mcp_server`) are **stdio processes the Claude/Codex CLI spawns per-turn** — there is nothing for systemd to keep "active." The correct liveness proof for stdio MCP servers is the import + tool-registry check above, which is what was run.

## Bottom line

**Zero regression.** Every BEFORE value reproduced exactly AFTER. The bundled-GDAL prediction from Phase 1a held: the service venv's rasterio still resolves its own `rasterio.libs/libgdal-…so` (GDAL 3.12.1), completely untouched by the system GDAL 3.8.4 that QGIS pulled in.

Hard stop at end of Phase 1e. Phase 2 (qgis-mcp plugin clone + install + 127.0.0.1:9876 socket) awaits explicit confirmation.
