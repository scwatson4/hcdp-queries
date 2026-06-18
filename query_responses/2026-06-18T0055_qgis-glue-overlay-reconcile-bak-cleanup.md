# Query: Reconcile working-tree overlays vs origin/qgis-glue + delete .bak backups

**Date:** 2026-06-18 00:55 UTC
**Scope:** read-only drift verification on `/opt/hcdp/src`, then cleanup. Only writes were
re-checkouts from `origin/qgis-glue` (none needed) and deleting `*.bak` backups. No commit/push,
no branch switch, no service restart, no firewall/data changes. Branch stayed
`claude/integrate-pipeline-codex-OMPo2`.

---

## 1. Overlay drift table — all MATCH, nothing re-checked-out

```
MATCH chatbot/hcdp_raster_client.py
MATCH services/jetstream2/raster_service/routes.py
MATCH services/jetstream2/instance_healthcheck.sh
MATCH services/jetstream2/probe_datatypes.py
MATCH shared/style_presets.json
```

`git diff --quiet origin/qgis-glue -- <file>` returned clean for all five → no DRIFT → no
re-checkout required. The pre-existing overlays already equal `origin/qgis-glue`.

## 2. `.bak` backups removed (exactly these 10)

```
chatbot/hcdp_raster_client.py.20260617T042048Z.bak
chatbot/raster_spec.py.20260615T013136Z.bak
chatbot/raster_spec.py.20260617T042048Z.bak
chatbot/raster_spec.py.20260617T051759Z.bak
jetstream2/agent_reference/raster_recipes.md.20260617T042048Z.bak
jetstream2/agent_reference/raster_recipes.md.20260617T051759Z.bak
jetstream2/agent_reference/raster_recipes.md.20260617T210428Z.bak
services/jetstream2/raster_service/routes.py.20260617T042048Z.bak
tools/hcdp_raster_mcp_server.py.20260615T013136Z.bak
tools/hcdp_raster_mcp_server.py.20260617T042048Z.bak
```

Listed via `git ls-files --others --exclude-standard | grep '\.bak$'`, then removed exactly those
paths. Verified `0` `.bak` files remain afterward.

## 3. Import sanity check → `imports OK`

```
imports OK
```

Caveat (environment, not code): the bare system `python3` and `/opt/hcdp/venv` **lack `httpx`**,
so the check as written fails at `import hcdp_raster_client` with
`ModuleNotFoundError: No module named 'httpx'`. `raster_spec` and `derived_rasters` import fine;
only `hcdp_raster_client` pulls in `httpx`. Running the identical check under the venv that holds
the runtime deps — `/opt/hcdp/raster_service/.venv` (httpx 0.28.1) — returns a clean `imports OK`.
The runtime that actually serves these (raster service / per-query MCP spawn) has `httpx`, so this
is a checker-interpreter mismatch, not drift from the reconcile.

## Result

All five overlays confirmed in sync with `origin/qgis-glue` (no re-checkout needed); 10 stale
`.bak` backups removed; imports clean in the proper venv. No commit/push, no branch switch, no
service restart; firewall and data untouched.
