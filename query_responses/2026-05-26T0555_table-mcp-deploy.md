# Query: Deploy table_mcp_server (new) and bring codex CLI to parity with claude

**Date:** 2026-05-26 05:55 UTC
**Branch:** `claude/integrate-pipeline-codex-OMPo2` at commit `3751162` ("Add render_table MCP tool + inline TableBlock (TanStack)")

A new FastMCP server (`tools/table_mcp_server.py`) ships in the HCDP repo with one tool, `render_table`, mirroring the existing chart-server pattern. Goals: deploy alongside the existing servers and bring codex CLI's MCP config to parity with claude's (which already had `hcdp-charts` + `hcdp-raster`; codex was missing the new `hcdp-tables`).

---

## Discovered paths

- **Python binary:** `/opt/hcdp/raster_service/.venv/bin/python3`
- **Repo root:** `/opt/hcdp/src` (existing servers are symlinked from `/opt/hcdp/mcp/*.py` into `/opt/hcdp/src/tools/`)
- **Working tree was clean** before checkout; switched to `claude/integrate-pipeline-codex-OMPo2`, fast-forward to `3751162`.

## Pre-flight smoke import

```
$ /opt/hcdp/raster_service/.venv/bin/python -c "
    import sys; sys.path.insert(0, 'tools')
    from table_mcp_server import mcp
    tools = mcp._tool_manager._tools
    print('tools:', list(tools))
  "
tools: ['render_table']
```

Imports cleanly. `render_table` registered as expected. No extra deps needed — fastmcp + mcp already present in the venv.

## Files touched

| File | Change |
|------|--------|
| `/opt/hcdp/mcp/table_mcp_server.py` | new symlink → `/opt/hcdp/src/tools/table_mcp_server.py` (mirrors the pattern used for chart and raster) |
| `~/.claude.json` | added `mcpServers.hcdp-tables` (backup at `~/.claude.json.bak-pre-tables-mcp`); `hcdp-charts` and `hcdp-raster` byte-identical to before |
| `~/.codex/config.toml` | appended `[mcp_servers.hcdp-tables]` block; existing blocks unchanged |

All edits idempotent — re-running the registration step won't duplicate entries.

## Diff summary

**`~/.claude.json`** — added one entry under `mcpServers`:

```json
"hcdp-tables": {
  "command": "/opt/hcdp/raster_service/.venv/bin/python3",
  "args": ["/opt/hcdp/mcp/table_mcp_server.py"]
}
```

**`~/.codex/config.toml`** — appended:

```toml
[mcp_servers.hcdp-tables]
command = "/opt/hcdp/raster_service/.venv/bin/python3"
args = ["/opt/hcdp/mcp/table_mcp_server.py"]
```

## Codex sees it

```
$ codex mcp list

Name         Command                                     Args                                     Env                                                    Status   Auth
hcdp-charts  /opt/hcdp/raster_service/.venv/bin/python3  /opt/hcdp/mcp/chart_mcp_server.py        -                                                      enabled  Unsupported
hcdp-raster  /opt/hcdp/raster_service/.venv/bin/python3  /opt/hcdp/mcp/hcdp_raster_mcp_server.py  HCDP_RASTER_API_KEY=*****, HCDP_RASTER_BASE_URL=*****  enabled  Unsupported
hcdp-tables  /opt/hcdp/raster_service/.venv/bin/python3  /opt/hcdp/mcp/table_mcp_server.py        -                                                      enabled  Unsupported
```

All three present and enabled. **Codex CLI is now at parity with Claude CLI** on this host.

## Allowlist note

No local Claude allowlist is configured here — `~/.claude/settings.local.json` only contains `Skill(update-config)`. The allowlist for hcdp-* tools is set backend-side via `--allowedTools` flags. **The new tool name to add to the chatbot's `JETSTREAM2_CLAUDE_FLAGS` is:**

```
--allowedTools mcp__hcdp-tables__render_table
```

If `JETSTREAM2_CLAUDE_FLAGS` already has other `--allowedTools` entries, either append the new tool to the existing comma-separated list or add another `--allowedTools` flag (Claude CLI accepts both).

## Services

Nothing restarted. The chatbot backend will pick up `hcdp-tables` on the next remote claude/codex session it spawns (MCP servers are launched per-session as subprocesses).
