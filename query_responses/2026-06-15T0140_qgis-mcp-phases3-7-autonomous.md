# QGIS + MCP integration — autonomous Phases 3→7 (final report)

**Date:** 2026-06-15 ~01:40 UTC
**Mode:** ran Phases 3–7 unattended (operator away), safe defaults, snapshot exists.
**Result:** all phases completed. QGIS-derived raster pipeline validated end-to-end on
the instance. Nothing hit the HARD-STOP rules. One pre-existing exposure flagged (VNC),
not changed.

---

## Phase 3 — Launch QGIS + verify socket ✅

- **Launch mechanism (decision):** systemd **user** service
  `~/.config/systemd/user/qgis-mcp.service`, running `qgis --nologo` on the existing
  TurboVNC display `:1` (the Guacamole web desktop). Chosen over tmux for clean
  unattended lifecycle + restart. Offscreen was attempted first but QGIS desktop
  refuses headless ("non-interactive mode not supported").
- **Blocker found + fixed:** QGIS hung forever during `QgisApp` construction in
  `QgsAuthManager::createAndStoreRandomMasterPasswordInKeyChain()` → the GNOME
  keyring (no GUI to answer the unlock prompt on VNC). Root-caused via a gdb
  backtrace of the stuck main thread. Fixed by setting `[auth] use_password_helper=false`
  in the profile `QGIS3.ini` (set via QGIS's own `QgsSettings` API to get the exact
  key). After that QGIS loaded all plugins and the **native plugin autostart** bound
  the socket.
- **Socket:** `127.0.0.1:9876` LISTEN, owned by `qgis.bin`. **Loopback only.**
- **No new public ports:** the `0.0.0.0` set is identical to the Phase-0 baseline
  (22, 5432, 5901, 8000, 49528). 9876 is not among them.

## Phase 4 — uv + register qgis MCP with both CLIs ✅

- **uv 0.11.21** installed user-local (`~/.local/bin`, standalone installer, no sudo).
- **Claude CLI** (user scope) and **Codex CLI** both registered `qgis` as a stdio
  server: `uvx --from /opt/qgis-mcp/repo qgis-mcp-server`, env
  `QGIS_MCP_HOST=127.0.0.1 / PORT=9876 / TOOL_MODE=granular`. (Used the **local clone**
  path, not the GitHub archive — pinned + offline-capable for the demo.)
- `claude mcp list` → `qgis: ✓ Connected` (uvx built the env, connected to the socket).
- Live check via the plugin protocol: `ping → pong`, `diagnose → healthy` (plugin
  0.4.7; providers 3d/gdal/grass/model/native/project/qgis/script).
- **execute_code:** the fork has **no env/setting to disable an individual tool**
  (only TOOL_MODE + HOST/PORT/TRANSPORT/LOG). Left in place per the standing rule
  (did **not** edit the plugin). Mitigations: socket is loopback-only; the tool is
  annotated `destructive` and elicits confirmation in Claude. Flagged in the setup doc.

## Phase 5 — Deploy the qgis-glue repo files ✅

- Backed up (timestamped `.bak`): `tools/hcdp_raster_mcp_server.py`,
  `chatbot/raster_spec.py`, and `~/.claude.json`. (`derived_rasters.py` and
  `shared/style_presets.json` were new — nothing to back up.)
- `git fetch origin qgis-glue` (d611e9c); brought in **exactly** four files via
  `git checkout origin/qgis-glue -- …` **without switching the deployment branch**
  (still on `claude/integrate-pipeline-codex-OMPo2`):
  `tools/hcdp_raster_mcp_server.py`, `chatbot/raster_spec.py`,
  `chatbot/derived_rasters.py` (new), `shared/style_presets.json` (new).
- `QGIS_OUTPUT_DIRS=/opt/qgis-mcp/out` added to the **hcdp-raster** env block in
  **both** CLI configs. `DERIVED_RASTER_DIR` deliberately **not** set (laptop-side).
- **Regression check (live):** raster MCP now **8 tools** (prior 7 +
  `publish_derived_raster`, all prior names unchanged), charts=1 (`render_chart`),
  tables=1 (`render_table`), raster service `/health` 200. No rollback needed.

## Phase 6 — End-to-end validation (native QGIS tools → publish) ✅

Driven over the plugin socket (the MCP tools aren't live in an already-running CLI
session; the socket client exercises the **identical** QGIS-side handlers the MCP
tools wrap). The publish step was invoked from the raster-service venv (the same
code the MCP tool runs).

1. **Climatology (decision):** `rainfall_climatology_1991_2010_annual.tif` in
   `/media/volume/hcdp_rasters/derived/` — the HCDP 1991–2010 annual rainfall
   climatology (Rainfall-Atlas/Giambelluca-derived). EPSG:4326, 2288×1520, 183–9276 mm.
2. **Island polygons (decision):** `/opt/hcdp/data/hawaii_islands.geojson` (preferred
   vector file; 8 polygons, EPSG:4326, `name` field with ʻokina spellings). The
   PostGIS `hawaii_islands` table exists but its geometry column isn't `geom`; the
   geojson was the cleaner, password-free source.
3. **Zonal mean annual rainfall (mm):** Hawaiʻi **1599**, Maui 1807, Oʻahu 1429,
   Kauaʻi 1869, Molokaʻi 1229, Lānaʻi 497, Kahoʻolawe 389, Niʻihau **NULL** (small/dry
   — no raster cells under the polygon). Big Island mean > 0 ✓.
4. **Wet-mask:** `raster_calculator` `clim@1 >= 6000` → `/opt/qgis-mcp/out/wet_mask.tif`
   — confirmed **single-band** GeoTIFF, EPSG:4326, values 0/1 (`gdalinfo`).
5. **Style + render:** `apply_style_qml` (singleband pseudocolor) + `render_map` →
   `/opt/qgis-mcp/test/wet_mask_render.png` (1000×700, **24.5 KB** > 20 KB).
6. **Publish:** `publish_derived_raster` on the mask → handle `kind="raster_spec"`,
   `datatype="derived"`, `derived_id` 32-hex (`c60f2ae8…19f`); `tif_base64` decoded to
   a valid 13.9 MB EPSG:4326 GeoTIFF. **Instance half of the pipeline proven.**

## Phase 7 — Docs + security sweep ✅

- Wrote `/opt/qgis-mcp/QGIS_MCP_SETUP.md` and `/opt/qgis-mcp/DEMO_RUNBOOK.md`.
- **Security sweep:** `9876` loopback-only; public listener set unchanged from
  Phase 0; no live credentials in any file written this session (the lone
  "password" match is the literal setting name `use_password_helper`); execute_code
  status documented.

## Anything skipped under HARD-STOP

None skipped. No firewall/security-group/ufw change, no new port opened, no Postgres
restart/reconfig, no `5432` exposure change, no user-data deletion.

## Flagged (not changed — pre-existing, would need an off-limits change)

- **TurboVNC `5901` is bound to `0.0.0.0`** (Jetstream2 image default; password +
  x509). Pre-existing from Phase 0, not introduced here. Restricting it to loopback
  is a firewall change (HARD-STOP) — left for the operator. The QGIS canvas is best
  viewed via the Guacamole web desktop or the documented SSH tunnel
  (`ssh -L 5901:127.0.0.1:5901 …`).
- **`execute_code` cannot be disabled via config** in this fork (documented above).

## Laptop steps the operator must run (when back)

1. **Deploy the glue on the laptop backend:** `git pull` / checkout `qgis-glue`
   (HEAD d611e9c) on the chatbot backend, then **restart uvicorn**.
2. **Optionally set `DERIVED_RASTER_DIR`** on the laptop (defaults to
   `chatbot/data/derived/`) — this store lives on the laptop, not the instance.
3. **Run one chat query that asks for a QGIS-derived map**, e.g.
   *"mask Big Island rainfall climatology to cells above 6000 mm and show it"*,
   in either Codex or Claude mode, and confirm the derived layer renders inline
   with click-to-inspect.

**The end-to-end chat render is NOT verified here** — it requires the laptop
backend (the `tif_base64` handle is consumed by the laptop's interceptor + frontend).
This report verifies everything up to and including the instance producing a valid
publish handle + GeoTIFF.

## Quick health re-check (anytime)

```bash
export XDG_RUNTIME_DIR=/run/user/$(id -u)
systemctl --user status qgis-mcp.service
ss -tlnp | grep 9876
python3 /tmp/qmcp.py ping '{}'
curl -s http://127.0.0.1:8000/health
```

## Rollback (Phase 5) if ever needed

```bash
cd /opt/hcdp/src
cp tools/hcdp_raster_mcp_server.py.20260615T013136Z.bak tools/hcdp_raster_mcp_server.py
cp chatbot/raster_spec.py.20260615T013136Z.bak           chatbot/raster_spec.py
rm chatbot/derived_rasters.py shared/style_presets.json   # the new files
# restore ~/.claude.json from ~/.claude.json.20260615T013136Z.bak if needed
```
