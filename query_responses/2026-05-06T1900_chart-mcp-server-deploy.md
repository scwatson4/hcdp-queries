# Query: Register the chart_mcp_server alongside the existing hcdp-raster MCP

**Date:** 2026-05-06 19:00 UTC
**Branch:** `claude/skip-pipeline-claude-mode-mZwRB`
**HEAD expected:** `04b0cef` ("Render Apache ECharts inline in Claude mode via render_chart MCP tool")

A new FastMCP server (`chart_mcp_server.py`) was added to the same repo for inline Apache ECharts rendering in Claude mode. It exposes one tool, `render_chart`, with an Abela-style picker that selects a chart type when none is specified.

---

## Results

| Item | Result |
|------|--------|
| **HEAD short SHA after pull** | `04b0cef` ✓ |
| **`readlink /opt/hcdp/mcp/chart_mcp_server.py`** | `/opt/hcdp/src/tools/chart_mcp_server.py` (target exists ✓) |

## Step 3 — import sanity check

```
signature: ['intent', 'title', 'data', 'chart_type', 'x_label', 'y_label']
builders: ['bar', 'boxplot', 'candlestick', 'funnel', 'gauge', 'graph', 'heatmap', 'line', 'parallel', 'pie', 'radar', 'sankey', 'scatter', 'sunburst', 'treemap']
```

Both lines match the expected output exactly — six parameters, fifteen builders.

## Step 5 — explicit Bar Chart end-to-end

```
- chart_type_used: `bar`
- abela_recommendation.primary: `Bar Chart`
- echarts_option contains a 'series' array: yes
```

All three expected values match.

## Step 6 — Abela default picker (no chart_type specified)

```
chart_type_used: line
abela_recommendation.primary: Line Chart
abela_recommendation.reasoning: intent describes change over time → Line Chart
```

Matches the expected `chart_type_used="line"`, `primary="Line Chart"`, and reasoning mentions "change over time".

## `hcdp-raster` integrity check

After the edit to `~/.claude.json`, the existing `hcdp-raster` entry is **byte-for-byte identical** to its pre-edit form (verified via `json.dumps(..., sort_keys=True)` comparison before/after the write). Both servers are now registered:

```
mcpServers keys: ['hcdp-raster', 'hcdp-charts']
```

## Backups

- `~/.claude.json.bak-pre-charts-mcp` — snapshot before this change

## Deviations

**One** — same `fastmcp` 3.2.4 surface quirk as the previous re-verify deploy. Step 3's one-liner used `m.mcp.tools['render_chart']`, which raised `AttributeError: 'FastMCP' object has no attribute 'tools'`. The actual registry is at `m.mcp._tool_manager._tools`, accessed as `tool.fn` to get the underlying function. After the one-attribute correction, output matched the expected lines exactly. The server itself is fine; this is purely a quirk in the import-sanity check command.

## Constraint compliance

- No `git commit` / `git push` from this host ✓
- `hcdp-raster` registration not modified ✓
- Stopped on the introspection `AttributeError`, diagnosed, resumed with the same one-line attribute fix from last time, flagged here ✓
