# Query: Vendor /opt/hcdp host services into hcdp-ai-interface, Phase 1

**Date:** 2026-06-10 22:15 UTC
**Mode:** vendoring + Phase 1 symlink swap + 4-curl verification + secondary leak redaction. Two commits pushed to private branch `claude/integrate-pipeline-codex-OMPo2`. Live secret strings have been replaced with placeholders throughout this report.

---

## Commits pushed

Branch: `claude/integrate-pipeline-codex-OMPo2` in private repo `hcdp-ai-interface`.

| Hash | Message | Files |
|------|---------|-------|
| **`d7a753f`** | Vendor /opt/hcdp host services (pristine + X-Island fix, docs sanitized) | 13 files, +3627 lines under `services/jetstream2/` |
| **`836e696`** | Redact live DB password from postgres_client docstring example | `chatbot/postgres_client.py:14` (1 line) |

## Pre-commit leak-check

Three known secret literals were scrubbed and the entire `/opt/hcdp/src/` tree grep'd for residuals:

| Secret class | Source `.env` var | Hits across repo after sanitization |
|---|---|---|
| Raster service API key | `API_KEY` | **0** (was 6 in the imported docs; replaced with `${HCDP_RASTER_API_KEY}`) |
| Postgres role password | embedded in `HCDP_DB_URI` | **0** post-commit-836e696 (was 1 pre-existing hit in `chatbot/postgres_client.py:14`) |
| Upstream HCDP API token | `HCDP_API_TOKEN` | **0** |

The pre-existing DB password leak was unrelated to the vendoring import — it was a hardcoded example in a docstring committed `a3b194a` (2026-04-08). Redacted in a separate second commit (`836e696`) per the agreed split.

## Vendoring layout (final)

```
hcdp-ai-interface/services/jetstream2/
├── README.md                      ← from scaffold commit f7fe5c1
├── hcdp_raster.py                 ← from /opt/hcdp/hcdp_raster.py
├── hcdp_raster_cli.py             ← from /opt/hcdp/hcdp_raster_cli.py
├── ingest.py                      ← from /opt/hcdp/ingest.py
├── backfill.sh                    ← from /opt/hcdp/backfill.sh
├── run.sh                         ← from /opt/hcdp/run.sh
└── raster_service/
    ├── auth.py                    ← from /opt/hcdp/raster_service/auth.py
    ├── main.py                    ← from /opt/hcdp/raster_service/main.py
    ├── overlay.py                 ← from /opt/hcdp/raster_service/overlay.py
    ├── routes.py                  ← from /opt/hcdp/raster_service/routes.py  *(WITH X-Island fix)*
    ├── requirements.txt
    ├── .env.example               ← new; var names mirror host .env, values blank
    ├── HANDOFF_TO_CHATBOT.md      ← sanitized
    └── INTEGRATION.md             ← sanitized
```

`.env`, `.venv`, `service.log` — not committed (gitignored belt-and-suspenders + never staged).

## Phase 1 symlink swap

Service stopped, 5 raster_service code files moved aside to `*.pre-vendor`, replaced with symlinks pointing into the checkout, service restarted:

| Symlink (live path) | → Target |
|---|---|
| `/opt/hcdp/raster_service/auth.py` | `/opt/hcdp/src/services/jetstream2/raster_service/auth.py` |
| `/opt/hcdp/raster_service/main.py` | `…/main.py` |
| `/opt/hcdp/raster_service/overlay.py` | `…/overlay.py` |
| `/opt/hcdp/raster_service/routes.py` | `…/routes.py` |
| `/opt/hcdp/raster_service/requirements.txt` | `…/requirements.txt` |

`.env` (real file), `.venv` (real dir), `service.log` (real file) untouched. Five `*.pre-vendor` backups preserved alongside each symlink for rollback. Systemd unit unchanged. Service downtime ~2 s.

## Four-curl verification matrix

| # | Endpoint | Island | Status | Bytes | PNG magic |
|---|---|---|---|---|---|
| 1 | `/raster/anomaly/overlay.png` | `Hawaiʻi` | **200** | 73,902 | `89 50 4E 47` ✓ |
| 2 | `/raster/anomaly/overlay.png` | `Maui` | **200** | 20,635 | `89 50 4E 47` ✓ |
| 3 | `/raster/overlay.png` | `Hawaiʻi` | **200** | 103,021 | `89 50 4E 47` ✓ |
| 4 | `/raster/anomaly/overlay.png` | (statewide) | **200** | 98,461 | `89 50 4E 47` ✓ |

Byte sizes match the post-fix baseline byte-for-byte (from this morning's X-Island fix session). Response header `X-Island: Hawaii` (ASCII-folded) confirmed. Service `active`, `/health` OK.

## Service status

- `systemctl is-active hcdp-raster-service` → `active`
- Symlinks resolve; `cat /opt/hcdp/raster_service/routes.py` returns the file currently in HEAD of the vendored repo
- `*.pre-vendor` backups present at: `auth.py.pre-vendor` (516 B), `main.py.pre-vendor` (1,402 B), `overlay.py.pre-vendor` (5,231 B), `routes.py.pre-vendor` (16,628 B), `requirements.txt.pre-vendor` (182 B). All match the on-host content from pre-symlink and stay there until you say otherwise.

---

## TOP FINDING — pre-existing DB password leak (rotation checklist)

The postgres role's password literal was hardcoded into a docstring example in `chatbot/postgres_client.py:14` and committed on **2026-04-08** (commit `a3b194a`, "Connect SQL agent and Postgres client to HCDP production database"). Commit `836e696` (this session) removes it from `HEAD` but **does not rewrite history** — anyone with clone access to the private `hcdp-ai-interface` repo can still see it via `git log -p`.

### Where the password literal currently lives on this host

| Location | What it is | Action |
|---|---|---|
| Postgres role `postgres` itself | The actual credential | `ALTER USER postgres PASSWORD '<new>';` via `sudo -u postgres psql`. Do this **first**. |
| `/opt/hcdp/.env` → `HCDP_DB_URI` line | Read by `run.sh` (cron) and `hcdp_raster_cli` | Replace password substring; no service restart needed (cron re-sources every run) |
| `/opt/hcdp/raster_service/.env` → `HCDP_DB_URI` line | Read by the FastAPI service via `load_dotenv` | Replace password substring; `sudo systemctl restart hcdp-raster-service` |
| `/opt/hcdp/SCHEMA_CONTEXT.md` line 8 | Documentation file with the password embedded as a DSN example | Replace password substring with `<password>` placeholder |
| Laptop chatbot `.env` (not visible from this host) | Whichever var the chatbot uses for HCDP DB connectivity | Coordinated update — otherwise chatbot's Postgres MCP loses connectivity at first attempt |

### Critical Postgres-side hardening to consider alongside rotation

`/etc/postgresql/16/main/pg_hba.conf` contains this line:

```
host hcdp postgres 0.0.0.0/0 scram-sha-256
```

That lets the `postgres` superuser connect from **anywhere on the public internet** using only the password. Whether port 5432 is reachable depends on the Jetstream2 security group, but defense-in-depth says replace `0.0.0.0/0` with the chatbot's egress CIDR (or `127.0.0.1/32` if the chatbot connects via SSH tunnel). The published 2-month-old leak in git history is exploitable for as long as both (a) the password isn't rotated, and (b) `0.0.0.0/0` stays in `pg_hba.conf`.

### False positives confirmed during the survey

- `/opt/hcdp/data/hawaii_islands.geojson` — substring match was a longitude coordinate (`-158.255…`) on Oʻahu, not the password
- `/home/exouser/.local/share/claude/versions/*` — Claude binary strings, not credentials

### Truly local / not pushed anywhere

- `/home/exouser/.claude/history.jsonl`, `~/.claude/file-history/*`, `~/.claude/projects/.../*.jsonl` — Claude Code conversation buffers that captured the earlier `sudo cat .env` output. Local to the `exouser` account; not in any repo or remote. Will roll over with use, but if account access is shared with another human/agent they're another exposure surface.

Rotation execution is deliberately not done in this session — coordinated from the laptop side per your instruction.

---

## Phase 2 readiness

Cron schedule:
```
*/15 * * * * /opt/hcdp/run.sh --update >> /opt/hcdp/cron.log 2>&1
0 */6  * * * /opt/hcdp/run.sh --refresh-views >> /opt/hcdp/cron.log 2>&1
```

`--update` fires every 15 min on the UTC quarter-hour. Next windows after Phase 1 completion (~22:14 UTC): **22:30 UTC**, then 22:45, 23:00, etc. The raster_service swap doesn't touch `run.sh` or `ingest.py`, so the next ingest tick should be uneventful, but the README's "wait for a clean cron cycle" rule is the safe path. Recommend reviewing `/opt/hcdp/cron.log` and the `ingest_log` table after the 22:30 firing before scheduling Phase 2 (data-layer symlinks for `hcdp_raster.py`, `ingest.py`, `backfill.sh`, `run.sh`, `hcdp_raster_cli.py`).
