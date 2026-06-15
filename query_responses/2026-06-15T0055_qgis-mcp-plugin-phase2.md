# Query: Install QGIS MCP plugin + server — Phase 2

**Date:** 2026-06-15 00:55 UTC
**Mode:** plugin install + auto-start config + output dirs. No QGIS launch yet (that's Phase 3). No MCP-client registration (that's Phase 4). Hard stop at end of Phase 2.

---

## Fork identity (important — not the original)

Cloned **`nkarasiak/qgis-mcp`** to `/opt/qgis-mcp/repo` — a heavily expanded fork of the original `jjsantos01/qgis_mcp`. Plugin version **0.4.7**, compatible QGIS 3.28–4.99 (we're on 3.44.7). It ships **102 MCP tools** in granular mode (default) or ~23 grouped tools in compound mode.

Architecture: `Claude ←→ MCP server (FastMCP, runs OUTSIDE QGIS via uvx) ←→ TCP socket ←→ QGIS plugin (QTimer event loop) ←→ PyQGIS`.

## 2a–2b — plugin installed

- Repo: `/opt/qgis-mcp/repo` (owned by `exouser`)
- Plugin symlinked into the default profile (same target name `install.py` uses):
  ```
  ~/.local/share/QGIS/QGIS3/profiles/default/python/plugins/qgis_mcp_plugin
      → /opt/qgis-mcp/repo/qgis_mcp_plugin
  ```
- Profile did not exist (QGIS never launched); created `python/plugins/` and `QGIS/` under the default profile.
- Plugin **enabled** in `QGIS3.ini`:
  ```ini
  [PythonPlugins]
  qgis_mcp_plugin=true
  ```

## 2c — auto-start mechanism (this fork has it built in)

The fork has a **native auto-start setting** — no custom `startup.py` needed. In `plugin.py`:
- `SETTINGS_PREFIX = "qgis_mcp"`
- On plugin `initGui()` (line 3724-3727): `if autostart: self.toggle_server(True)` — starts the socket server automatically when QGIS loads the plugin.
- Port read from QSettings `qgis_mcp/port` (default `_DEFAULT_PORT = 9876`).

Config written to `QGIS3.ini`:
```ini
[qgis_mcp]
autostart=true
port=9876
```

### Localhost-only by construction (code-level; bind check is Phase 3)

Host is **hardcoded** `_DEFAULT_HOST = "localhost"` (plugin.py:144) and the server is instantiated with only `port=` overridden (plugin.py:3913) — host is never taken from settings or made configurable. The socket is `AF_INET` (IPv4) and binds `(self.host, self.port)` = `("localhost", 9876)` → **127.0.0.1:9876**. There is no code path that binds `0.0.0.0`. The actual `ss -tlnp` verification happens in Phase 3 after launch, but at the source level it cannot bind a public interface without editing the plugin.

## 2d — install.py NOT run (per instruction)

Did **not** run `python install.py`. Confirmed neither MCP-client config was touched:
- `~/.claude.json`: no `qgis` entry (0 matches)
- `~/.codex/config.toml`: no `mcp_servers.qgis` entry (0 matches)

Claude + Codex registration is deferred to Phase 4 (manual).

## 2e — output directories

```
/opt/qgis-mcp/out   (exouser:exouser, 755, write-tested OK)  ← chatbot glue will whitelist this via QGIS_OUTPUT_DIRS
/opt/qgis-mcp/test  (exouser:exouser, 755, write-tested OK)  ← Phase 5 validation outputs
```

QGIS runs as `exouser`; both dirs are writable by that user.

---

## The 102 granular tool names (authoritative — extracted from `@mcp.tool` decorators in `src/qgis_mcp/server.py`)

You asked for the exact names so the chat UI's tool-call labels line up. This is the registered list, not the README's category summary.

**System / health (5):** `ping`, `diagnose`, `get_qgis_info`, `get_message_log`, `execute_code`

**Project (4):** `get_project_info`, `load_project`, `create_new_project`, `save_project`

**Layers — add/remove/find (9):** `get_layers`, `add_vector_layer`, `add_raster_layer`, `remove_layer`, `find_layer`, `create_memory_layer`, `add_web_layer`, `duplicate_layer`, `get_active_layer`

**Layer state/props (10):** `set_layer_visibility`, `zoom_to_layer`, `set_active_layer`, `set_layer_property`, `get_layer_extent`, `get_layer_crs`, `set_layer_crs`, `get_layer_labeling`, `set_layer_labeling`, `set_layer_order`

**Features (8):** `get_layer_features`, `get_field_statistics`, `add_features`, `update_features`, `delete_features`, `select_features`, `get_selection`, `clear_selection`

**Fields (5):** `add_field`, `delete_field`, `rename_field`, `add_table_join`, `get_unique_values`

**Styling (4):** `set_layer_style`, `apply_style_qml`, `save_style_qml`, `area_m2`

**Canvas / render (8):** `get_canvas_extent`, `set_canvas_extent`, `get_canvas_screenshot`, `get_canvas_scale`, `set_canvas_scale`, `render_map`, `get_raster_info`, `sample_raster_values`

**Processing (12):** `execute_processing`, `list_processing_algorithms`, `get_algorithm_help`, `create_processing_model`, `list_processing_models`, `run_model`, `get_processing_providers`, `execute_processing_batch`, `raster_calculator`, `zonal_statistics`, `spatial_join`, `export_layer`

**Layer tree / groups (3):** `get_layer_tree`, `create_layer_group`, `move_layer_to_group`

**Bookmarks (3):** `get_bookmarks`, `add_bookmark`, `remove_bookmark`

**Map themes (4):** `get_map_themes`, `add_map_theme`, `remove_map_theme`, `apply_map_theme`

**Project CRS / vars / settings (8):** `set_project_crs`, `get_project_variables`, `set_project_variable`, `validate_expression`, `get_setting`, `set_setting`, `transform_coordinates`, `batch_commands`

**Layouts & atlas (13):** `list_layouts`, `export_layout`, `create_layout`, `add_layout_map`, `get_layout_info`, `add_layout_label`, `add_layout_legend`, `add_layout_scalebar`, `add_layout_picture`, `add_layout_table`, `configure_atlas`, `export_atlas`, `remove_layout`

**Query (3):** `execute_sql`, `evaluate_expression`, `identify_features`

**Plugins (3):** `list_plugins`, `get_plugin_info`, `reload_plugin`

(Total: 102. Categories above are my grouping for readability; the registered names are flat.)

**Coverage note for the chat UI:** these names are generic QGIS verbs (`render_map`, `add_raster_layer`, `execute_processing`, etc.) and do **not** collide with the existing HCDP MCP tool names (`show_climate_raster_on_map`, `render_chart`, `render_table`, etc.). No label clashes expected. If you switch the server to compound mode (`QGIS_MCP_TOOL_MODE=compound`), the UI would instead see ~23 grouped names (`system`, `project`, `layer`, `features`, `render`, `processing`, …) each dispatched by an `action` parameter — worth deciding before Phase 4 since it changes every label.

## Note: uv/uvx still not installed

The Phase-4 registration pattern this fork uses is `uvx --from <github archive> qgis-mcp-server`. `uv`/`uvx` are **not yet on this host** (flagged in Phase 0). I'll need to install `uv` before Phase 4 can register the server — will surface that for approval when we get there.

## Stop point

Hard stop at end of Phase 2. Phase 3 (launch QGIS under the Guacamole desktop, verify `127.0.0.1:9876` is listening and nothing new on `0.0.0.0`) awaits your go.
