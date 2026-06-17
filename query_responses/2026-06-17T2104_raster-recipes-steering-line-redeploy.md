# Query: Re-pull raster_recipes.md from qgis-glue (recipe-7 steering line)

**Date:** 2026-06-17 21:04 UTC
**Scope:** pulled one markdown file from `qgis-glue` into the deployment checkout. Branch
stayed `claude/integrate-pipeline-codex-OMPo2`. No service restart (markdown read fresh via
workdir symlink). Did not touch raster service, qgis-mcp, Postgres, firewall, or VNC.

---

## Resolved qgis-glue commit

```
609efa3  Backlog: add map date-stepper + value-colored station markers
```

## The steering line — present (with a grep caveat)

The literal check `grep -n "Always use show_climate_raster_on_map"` returned **0 matches**,
but the steering line **is present** — the pattern (plain space) didn't account for a
backtick and a line wrap. Actual content at **line 190**, inside recipe `### 7. Stations on top`:

```
190:**Always use `show_climate_raster_on_map` with `show_stations=true` for any
```

(Found via `grep -ni "always use"`.) The full sentence steers the agent to use
`show_climate_raster_on_map` with `show_stations=true` for any "plot/show/map these
stations" question, and not to build a QGIS project for plotting points on a basemap.

## Deploy mechanics confirmed

- File updated: `jetstream2/agent_reference/raster_recipes.md` (via
  `git checkout origin/qgis-glue -- <path>`); branch not switched; `.bak` backup made
  (`…raster_recipes.md.20260617T210428Z.bak`).
- **Reads fresh in the workdir:** `~/hcdp-workdir/agent_reference` is a directory symlink →
  `/opt/hcdp/src/jetstream2/agent_reference`, and the file is confirmed same-inode
  (`test -ef` = YES). The next conversation picks it up with no restart.

## Result

The recipe-7 steering line is deployed and live (despite the literal grep miss, which was a
backtick/line-wrap artifact). This was the only instance-side change in the batch — the
execute_code gating and inline-image interceptor are laptop-side (claude_cli_runner flags +
interceptor + frontend), taking effect on the laptop after a pull + uvicorn/dev restart, no
instance action.

Not touched: raster service, qgis-mcp, Postgres, firewall, VNC.
