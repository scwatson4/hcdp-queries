# Query: Deploy show_climate_raster_on_map MCP tool + raster_spec.py

**Date:** 2026-06-10 01:25 UTC
**Branch:** `claude/integrate-pipeline-codex-OMPo2`
**HEAD after deploy:** `a27e92f` ("Spec-based raster maps: model emits a spec, browser renders the GeoTIFF")

Originally instructed to deploy only `chatbot/raster_spec.py`. Smoke test revealed the new tool was missing because `tools/hcdp_raster_mcp_server.py` had also been updated in the same upstream commit but wasn't reflected on the host. Paused, asked, then proceeded with **Option 2: full fast-forward** to converge the tree.

---

## Smoke test (final)

```python
from hcdp_raster_mcp_server import mcp
sorted(mcp._tool_manager._tools.keys())
# →
['compare_grid_to_stations', 'compute_island_anomaly', 'get_island_climate_stats',
 'list_climate_products', 'sample_climate_at_point', 'show_climate_overlay_on_map',
 'show_climate_raster_on_map']

count: 7
new tool present: True
```

`show_climate_raster_on_map` ✓ registered alongside the six existing tools. No `ModuleNotFoundError`.

## Deploy steps executed

1. **Pre-flight `git status`** — no modifications to tracked files; only the staged `raster_spec.py` from my earlier targeted checkout. Branch was actually **6 commits behind origin**, not just one. Six commits about to ride in:
   ```
   a27e92f  Spec-based raster maps: model emits a spec, browser renders the GeoTIFF
   701b485  Inline AI mode selector in InputBar + harden circuit-breaker probe
   03e6c69  Skip temperature param for gpt-5 paraphrase models
   b347798  Add paraphrase circuit breaker + /api/health/llm + CODEX_DEBUG tracing
   42f2b5e  Make tool-call summaries climate-researcher-friendly + fix codex flags
   c7390db  Port runbook from add-codex branch: Jetstream2 IP rotation
   ```
2. **Cleared the staged file** so merge has a clean working tree: `git restore --staged chatbot/raster_spec.py && rm chatbot/raster_spec.py`.
3. **Fast-forward merge:** `git fetch origin && git merge --ff-only origin/claude/integrate-pipeline-codex-OMPo2`. Succeeded. HEAD is now at `a27e92f`, working tree clean.
4. **Smoke test** (above) — passes.

## MCP server file paths

| Item | Path |
|------|------|
| `hcdp_raster_mcp_server.py` (symlink) | `/opt/hcdp/mcp/hcdp_raster_mcp_server.py` |
| `hcdp_raster_mcp_server.py` (real file) | `/opt/hcdp/src/tools/hcdp_raster_mcp_server.py` |
| `hcdp_raster_client.py` | `/opt/hcdp/src/chatbot/hcdp_raster_client.py` |
| `raster_spec.py` (new) | `/opt/hcdp/src/chatbot/raster_spec.py` |

## MCP repo checkout

- **Root:** `/opt/hcdp/src`
- **Remote:** `github.com/scwatson4/hcdp-ai-interface` (private)
- **Branch:** `claude/integrate-pipeline-codex-OMPo2`
- **HEAD:** `a27e92f` — fully up to date with origin

## Workdirs (where claude / codex actually start)

The chatbot reads `JETSTREAM2_CLAUDE_WORKDIR` and `JETSTREAM2_CODEX_WORKDIR` from its laptop-side `.env`. Both runners on this host fail loudly if the env var is missing — there is no fallback.

The repo's `.env.example` defaults both to `/home/ubuntu/hcdp-queries`. On this Jetstream2 host the corresponding real workdir is **`/home/exouser/hcdp-queries/`** (user is `exouser`, not `ubuntu`).

- Git checkout of `scwatson4/hcdp-queries` (public), branch `main`, working tree clean
- **Different checkout** from `/opt/hcdp/src/` — two distinct clones:
  - `/opt/hcdp/src` — `hcdp-ai-interface` (private) — MCP servers + chatbot runners
  - `/home/exouser/hcdp-queries` — `hcdp-queries` (public) — `CLAUDE.md`, `agent_reference/`, query responses

## `agent_reference/` (inside the workdir)

```
README.md
connection.md
data_products.md
data_quality.md
geography.md
methodology.md
query_patterns.md
response_style.md
schema.md
stations.md
variables.md
```

11 files. Same set we've been maintaining.

## `CLAUDE.md` — present in claude workdir (54 lines)

Sets the HCDP query environment, lists `agent_reference/*.md` files, defines working rules (real psql only / read references first / prefer materialized views / always include units / state assumptions for ambiguous questions), gives a common access pattern (`mv_daily_station_summary_qc`), and the scope/refusal policy (HCDP-only, no web search, no external APIs).

## `AGENTS.md` — NOT present in codex workdir

```
ls: cannot access '/home/exouser/hcdp-queries/AGENTS.md': No such file or directory
```

This is the known gap: Codex CLI launches in the same workdir but gets no project-specific HCDP context — no scope, no pointer to `agent_reference/`, no QC discipline. The Codex side is running on `~/.codex/config.toml` defaults only (model + MCP servers wired up, no system-prompt content).

Lowest-effort fix is still: `cd /home/exouser/hcdp-queries && ln -s CLAUDE.md AGENTS.md`. One symlink, both agents read the same instructions, can't drift apart. Not done in this run — a deploy-only task.

## Deviation from script

Step 5 of the original instructions used `mcp.tools.keys()`. As before in this fastmcp 3.2.4 install, the tool registry is at `mcp._tool_manager._tools`, not `mcp.tools` (the latter raises `AttributeError`). One-line attribute correction, no functional change — same workaround used in the earlier MCP deploys. The smoke test reported above uses the corrected attribute.

## Nothing restarted

Per instructions, no services restarted. The chatbot backend will spawn a fresh MCP server subprocess on the next claude/codex turn from the laptop, and that subprocess will read the now-current `hcdp_raster_mcp_server.py` + `raster_spec.py`.
