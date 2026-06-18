# Query: Deploy 4 files from origin/qgis-glue onto the instance checkout

**Date:** 2026-06-18 00:40 UTC
**Scope:** working-tree overlay of four files from `origin/qgis-glue` into `/opt/hcdp/src`.
Branch stayed `claude/integrate-pipeline-codex-OMPo2`. No commit, no push, no branch switch, no
service restart, no firewall/data changes. qgis-glue advanced `609efa3 → b790a8a` on fetch.

---

## The four files (now at origin/qgis-glue versions)

```
A  chatbot/derived_rasters.py
M  chatbot/raster_spec.py
M  jetstream2/agent_reference/raster_recipes.md
M  tools/hcdp_raster_mcp_server.py
```

Each verified `MATCH` against `origin/qgis-glue` (`git diff --quiet origin/qgis-glue -- <file>`
returns clean for all four). Brought in via `git checkout origin/qgis-glue -- <paths>`.

## Python sanity checks (syntax/guard only — nothing restarted)

```
raster_spec + derived_rasters OK
mcp server parses OK
```

- `python3 -c "import raster_spec, derived_rasters"` (chatbot on path) → OK
- `python3 -c "ast.parse(open('tools/hcdp_raster_mcp_server.py').read())"` → parses OK

## Flag: working tree was not clean before the checkout

Per the "stop and show me if status lists anything other than those four paths" guardrail — the
tree already carried overlays from earlier authorized deploys this session, **before** this
checkout (not produced by it):

```
M  chatbot/hcdp_raster_client.py
A  services/jetstream2/instance_healthcheck.sh
A  services/jetstream2/probe_datatypes.py
M  services/jetstream2/raster_service/routes.py
A  shared/style_presets.json
?? <several timestamped *.bak backups from prior re-deploys>
```

This checkout touched only the four named files. The pre-existing entries were left exactly as
they were, pending any reconcile instruction.

## No restart needed

The recipe doc is re-read every turn, and the hcdp-raster MCP server is launched fresh on the
next `claude -p` query, so it picks up the new tools (`station_points`, `list_reference_maps`,
`show_reference_map`) and the publish-compression fix automatically.

## Result

Four files deployed to their `origin/qgis-glue` versions and load/parse clean; branch, commits,
services, firewall, and data all untouched.
