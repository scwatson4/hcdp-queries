# Query: Install a FastMCP server that exposes the HCDP raster endpoints to remote `claude -p` callers

**Date:** 2026-05-06 12:15 UTC
**Source repo:** `github.com/scwatson4/hcdp-ai-interface`, branch `claude/skip-pipeline-claude-mode-mZwRB`
**Files of interest:** `tools/hcdp_raster_mcp_server.py`, `tools/README.md`

---

## Discovery values

| Variable | Value |
|----------|-------|
| `$RUN_USER` | `exouser` |
| `$VENV_PY` | `/opt/hcdp/raster_service/.venv/bin/python3` |
| `$KEY` | sourced from `/opt/hcdp/raster_service/.env` (`API_KEY=...`, 43 chars). Referred to as `<key>` from here on — never echoed. |
| `~/.claude.json` | exists for `exouser`, 24,504 bytes |
| FastAPI service | `hcdp-raster-service.service` (systemd, active, listening on `0.0.0.0:8000`) |

## Steps executed

1. **Discovery (1-4)** — all four checks returned non-empty values.
2. **`pip install fastmcp httpx`** in the service venv — succeeded.
3. **Clone** — initial unauthenticated clone failed (private repo). Stopped and asked for credentials per the "do not improvise" constraint. Resumed once a PAT was provided.
4. **Symlink** — `/opt/hcdp/mcp/hcdp_raster_mcp_server.py` → `/opt/hcdp/src/tools/hcdp_raster_mcp_server.py`.
5. **Import sanity check** — script imported cleanly, no errors.
6. **Register in `~/.claude.json`** — added `mcpServers.hcdp-raster` entry with `command`, `args`, and `env` (`HCDP_RASTER_BASE_URL=http://127.0.0.1:8000`, `HCDP_RASTER_API_KEY=<key>`). Original file backed up to `~/.claude.json.bak-pre-mcp`. All 38 top-level keys preserved; this was the first `mcpServers` entry (key was created).
7. **Standalone `--list-tools`** — flag not implemented in the script (exit 0, no output). Skipped to step 10 per instructions.
8. **End-to-end via `claude -p`** — see verification section below.

## File locations

- **MCP server file:** `/opt/hcdp/mcp/hcdp_raster_mcp_server.py` (symlink)
- **Symlink target:** `/opt/hcdp/src/tools/hcdp_raster_mcp_server.py`
- **Source repo working tree:** `/opt/hcdp/src` (branch `claude/skip-pipeline-claude-mode-mZwRB`)
- **claude.json backup:** `~/.claude.json.bak-pre-mcp` (pre-modification snapshot, in case of rollback)

## Registered tool names (6 — expected ✓)

Confirmed by `grep -E "@mcp\.tool" /opt/hcdp/src/tools/hcdp_raster_mcp_server.py`:

1. `list_climate_products`
2. `sample_climate_at_point`
3. `get_island_climate_stats`
4. `compute_island_anomaly`
5. `compare_grid_to_stations`
6. `show_climate_overlay_on_map`

These appear in Claude as `mcp__hcdp-raster__<tool_name>`.

## End-to-end verification — last 30 lines

```
$ echo "List the climate products available via the hcdp-raster MCP." | \
    claude -p --mcp-debug \
      --allowedTools "mcp__hcdp-raster__list_climate_products"

The `list_climate_products` tool has a schema mismatch — it requires `args` and `kwargs`
parameters, but the underlying function rejects them. Either way it errors:

- Omitting them → Pydantic validation error ("Field required")
- Passing them (as strings or empty containers) → "got an unexpected keyword argument 'args'"

This appears to be a bug in the `hcdp-raster` MCP server's tool definition. You may want to
report it to the server maintainer. In the meantime, I can try the other hcdp-raster tools
(`sample_climate_at_point`, `get_island_climate_stats`, `compute_island_anomaly`,
`compare_grid_to_stations`, `show_climate_overlay_on_map`) if you can tell me a specific
product name to query, or we can inspect the server config to see if there's a workaround.
```

### What this tells us

- ✓ The MCP server is registered correctly in `~/.claude.json`
- ✓ Claude successfully launched it, connected over stdio, and discovered all 6 tools
- ✓ Claude attempted to call `mcp__hcdp-raster__list_climate_products`
- ✗ The call failed with a **schema mismatch in the upstream server code** — the `_wrap(fn)` decorator (line 65 of `hcdp_raster_mcp_server.py`) advertises `args`/`kwargs` in the JSON schema, but the wrapped function signature doesn't accept them.

This is a bug in the repo, not in the deploy. The fix likely belongs upstream — either drop `args`/`kwargs` from the wrapper signature, or have the wrapper accept-and-ignore them.

## Deviations from the script

1. **Step 6 (clone):** initial unauthenticated clone of `scwatson4/hcdp-ai-interface` failed (private repo). Per the "do not improvise" rule, stopped and asked. Resumed once a PAT was provided.
2. **Step 9 (`--list-tools`):** ran but produced no output and exited 0 — the flag isn't implemented. Skipped to step 10 as instructed.
3. **Step 10 invocation form:** initial `claude -p ... "prompt"` rejected with `"Input must be provided either through stdin or as a prompt argument when using --print"`. Re-ran with the prompt piped over stdin, which worked.

## What didn't get done / suggested follow-up

The end-to-end test surfaced a tool-schema bug upstream. **No code changes made on this host** per the deploy-only constraint. The fix probably belongs in the `hcdp-ai-interface` repo on the `claude/skip-pipeline-claude-mode-mZwRB` branch.

## Constraint compliance

- No `git commit` or `git push` from this host ✓
- `<key>` not echoed in this report ✓
- Stopped on the clone-auth failure and asked before improvising ✓
- All 38 pre-existing top-level keys in `~/.claude.json` preserved ✓
