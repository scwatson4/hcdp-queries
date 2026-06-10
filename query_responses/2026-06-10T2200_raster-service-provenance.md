# Query: Routine deploy + raster_service provenance investigation

**Date:** 2026-06-10 22:00 UTC
**Mode:** deploy (Task 1) + read-only recon (Task 2). Nothing moved, nothing committed.

---

## TASK 1 — Deploy verified ✓

Pulled `claude/integrate-pipeline-codex-OMPo2` on `/opt/hcdp/src`:

```
56ad49f..cab72a9  Map card polish: play button, labeled sliders, scale explainer, zoom fix
```

9 files / +517 lines including `tools/hcdp_raster_mcp_server.py` (island-name normalization + `scale` param), `jetstream2/agent_reference/raster_recipes.md` (Per-frame scale toggle, anomaly/difference/threshold guidance), `chatbot/raster_spec.py`, and the frontend `RasterSpecMap` updates.

### Verification greps (both hit)

```
$ grep -n "canonical_island_okina" tools/hcdp_raster_mcp_server.py | head -3
56:from raster_spec import build_raster_spec, canonical_island_okina  # noqa: E402  (sys.path tweak above)
156:        product=product, island=canonical_island_okina(island), date=date
182:        product=product, date=date, island=canonical_island_okina(island)

$ grep -n "Per-frame" jetstream2/agent_reference/raster_recipes.md | head -2
78:**Shared / Per-frame scale toggle**. These restyle instantly with no new

$ grep -n "Per-frame" ~/hcdp-workdir/agent_reference/raster_recipes.md
78:**Shared / Per-frame scale toggle**. These restyle instantly with no new
```

The third grep confirms the workdir symlinks resolve to the updated content. No restart needed — MCP servers spawn fresh per chatbot turn.

---

## TASK 2 — `/opt/hcdp/raster_service` provenance

### 1. Is it a git checkout? **No.**

```
$ git -C /opt/hcdp/raster_service status
fatal: not a git repository (or any of the parent directories): .git

$ git -C /opt/hcdp/raster_service remote -v
fatal: not a git repository (or any of the parent directories): .git
```

Walked up the tree — no `.git` in `/opt/hcdp/raster_service`, `/opt/hcdp`, or `/opt`. The only `.git` anywhere under `/opt/hcdp` is at `/opt/hcdp/src` (the `hcdp-ai-interface` checkout), which does **not** contain a `raster_service/` subdirectory.

### 2. Origin clues

- **Manual provisioning, single event, ~Apr 30.** Every code file's mtime is `Apr 30 08:55–09:00` except `routes.py` (my fix today). Owner is `exouser`, group `exouser` — not a service account, not root. Looks like a one-shot hand-build, not pulled from a repo.
- **`HANDOFF_TO_CHATBOT.md` (34 KB) is a deliverable, not docs from a repo.** Top line: *"You are being given access to a live HTTP service…"* — written for a chatbot integrator. Has the directive `> DO NOT COMMIT THIS FILE TO PUBLIC GIT. It contains the live API key.` This file *is* the source repo's substitute.
- **No `__init__.py`, no `pyproject.toml`, no `setup.py`, no `Dockerfile`, no `.gitignore`, no `README.md`.** Module headers are just `"""API key authentication."""` style — no copyright, no repo URL, no version string.
- **systemd unit hardcodes the path:** `WorkingDirectory=/opt/hcdp/raster_service`, `EnvironmentFile=/opt/hcdp/raster_service/.env`, `ExecStart=/opt/hcdp/raster_service/.venv/bin/uvicorn main:app …`. No `Provision-By:` comment or source reference.
- **Bash history is sparse** — one `scp hcdp_api__1_.yaml exouser@149.165.155.217:/opt/hcdp/` from before the raster_service was built, and no `scp`/`rsync` of raster_service code at all. Either rolled-over history or the directory was built in place on the host.
- **The raster_service is part of a larger untracked pattern** under `/opt/hcdp/`:

| Path | Size | Role |
|------|------|------|
| `/opt/hcdp/hcdp_raster.py` | 30.8 KB | Data layer — imported by `raster_service/main.py` |
| `/opt/hcdp/ingest.py` | 22.2 KB | Mesonet ingestion job (run by cron) |
| `/opt/hcdp/hcdp_raster_cli.py` | 3.4 KB | CLI wrapper around the data layer |
| `/opt/hcdp/backfill.sh` | 3.2 KB | Historical backfill helper |
| `/opt/hcdp/run.sh` | (not read) | Cron entrypoint |
| `/opt/hcdp/raster_service/` | 24 KB code | This service |

All hand-placed under `/opt/hcdp/`, all late-Apr provisioning, all outside any visible repo. **Drift risk isn't unique to raster_service** — it's a property of the whole `/opt/hcdp/` subtree.

### 3. Directory contents (size)

```
auth.py              516 B   FastAPI X-API-Key dependency
main.py            1,402 B   uvicorn entrypoint, FastAPI app, CORS
overlay.py         5,231 B   PNG/Leaflet rendering (untouched by my fix)
routes.py         16,628 B   all 13 endpoints (the file I edited today)
requirements.txt     182 B   pinned deps: fastapi/uvicorn/rasterio/numpy/matplotlib/…
HANDOFF_TO_CHATBOT.md  33,839 B  long-form handoff doc — contains live API key
INTEGRATION.md         20,063 B  integration guide — contains live API key
.env                 248 B   secret config — must NOT commit
.venv             ~418 MB    Python venv (regenerable from requirements.txt)
service.log         4,448 B  current run's log
__pycache__         44 KB    regenerable
```

**Code to vendor: ~24 KB across 4 .py files + 182-byte `requirements.txt`.** Docs add ~54 KB but require API-key scrubbing before they can go anywhere. Trivial vendoring job in size; the gating concern is secrets, not bytes.

### 4. Recommendation: **vendor into `hcdp-ai-interface` as `raster_service/`**

Same pattern as the recent `jetstream2/` migration for agent docs. Rationale:

- **It's already conceptually part of the chatbot stack.** `tools/hcdp_raster_mcp_server.py` is an HTTP client of this service; `chatbot/raster_spec.py` is shaped by its response contract. They drift apart at our peril and I just saw what that looks like (the X-Island latin-1 bug lived in a file the rest of the system couldn't review or regression-test).
- **My X-Island fix gets a permanent home.** Without this, the next reprovision wipes it and Hawaiʻi-overlay 500s come back silently.
- **Private repo means docs can be sanitized once and committed.** `HANDOFF_TO_CHATBOT.md` and `INTEGRATION.md` need the live API key replaced with `${HCDP_API_KEY}` references; after that they should live with the code they describe, not as files on disk only.
- **Code is too small for its own repo** (~24 KB / 4 files). A separate repo means another checkout to keep current, another deploy story, another set of permissions to manage. No benefit.
- **Symlink-based deploy is easy:**

  ```bash
  mv /opt/hcdp/raster_service /opt/hcdp/raster_service.bak
  ln -s /opt/hcdp/src/raster_service /opt/hcdp/raster_service
  # keep /opt/hcdp/raster_service.bak/.env and .venv in place
  # or recreate them under the symlinked location — both work
  ```

  Existing systemd unit needs no change because the path is preserved.

### Alternatives considered and rejected

- **Own repo `hcdp-raster-service`:** overhead exceeds the benefit for 24 KB of code with exactly one consumer.
- **Stay manual + document the manual steps:** doesn't address drift. The whole point of fixing this is so the next reprovision doesn't regress the fix.

### Suggested target layout once vendored (not done — read-only task)

```
hcdp-ai-interface/raster_service/
    auth.py          (vendored as-is)
    main.py          (vendored as-is)
    overlay.py       (vendored as-is)
    routes.py        (vendored WITH the X-Island fix)
    requirements.txt (vendored as-is)
    .env.example     (NEW — empty template, never commit real .env)
    INTEGRATION.md   (sanitized — API key replaced with ${HCDP_API_KEY})
    README.md        (NEW — systemd unit reference, deploy steps)
```

### Broader-scope flag (out of scope for this task)

`/opt/hcdp/hcdp_raster.py`, `/opt/hcdp/ingest.py`, `/opt/hcdp/backfill.sh`, `/opt/hcdp/run.sh`, `/opt/hcdp/hcdp_raster_cli.py` are also hand-placed and untracked, with the same Apr 30 provenance gap. A "vendor into hcdp-ai-interface" pass on `raster_service/` would naturally extend to these — they're the rest of the same lost subsystem. Worth deciding whether to do them in one wave (one PR, one symlink swap session) or sequentially.

Nothing moved, nothing committed.
