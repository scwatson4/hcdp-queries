# Query: Vendor /opt/hcdp host services into hcdp-ai-interface, Phase 2

**Date:** 2026-06-11 00:06 UTC
**Mode:** Phase 2 of the two-phase host-services migration. Data-layer files now symlinked from `/opt/hcdp/` into the version-controlled checkout. One commit pushed to private branch `claude/integrate-pipeline-codex-OMPo2`.

---

## Pre-swap health evidence

Phase 1 completed at ~22:14 UTC on 2026-06-10. The wait gate was "one clean cron cycle observed post-Phase-1." Actual evidence at swap time (00:04 UTC on 2026-06-11):

### `cron.log` tail (last 9 cron ticks before swap)

Every quarter-hour `--update` from `2026-06-10T21:50:00` through `2026-06-10T23:35:00` shows the same shape:

```
Incremental update from 2026-06-10T23:35:00...
  Fetched 10918 measurements (offset=0, total so far=10918)
  Upserted 10918 measurements
Fetching station monitor...
  Upserted 76 station monitor records
```

Range of fetch counts: 10,771 – 11,254 per 15-minute window. 76 stations reporting on every tick. No "Error" or "Traceback" anywhere in the post-22:14 portion.

### `ingestion_log` since Phase-1 swap

```
   job_type    | status  | n |       first_run_utc        |        last_run_utc        
---------------+---------+---+----------------------------+----------------------------
 refresh_views | running | 1 | 2026-06-11 00:00:02.036383 | 2026-06-11 00:00:02.036383
 update        | success | 8 | 2026-06-10 22:15:01.356813 | 2026-06-11 00:00:02.0365
```

**8/8 update runs successful.** The single `refresh_views=running` row is the live 6-hourly job that kicked off at 00:00 UTC — kicked off two minutes before my swap query and still in flight. Not a stale orphan; the orphan pattern from prior audits would have a `started_at` days in the past. The Python process for that run had already loaded the on-host `ingest.py` into memory before the swap, so it'll complete using the pre-symlink module — and future invocations get the symlinked copy.

### Latest mesonet timestamp

`MAX(timestamp) = 2026-06-10 23:50:00+00`, `now() = 2026-06-11 00:03:21 UTC` → 13 min lag, normal for the 15-min cron + upstream API publication delay.

### Note: prior reports mis-named the log table

The table is `public.ingestion_log` (not `ingest_log` as earlier audit reports said). The earlier name was wrong but the data was correct — same table, same column shape. Noted here so I don't repeat the mistake.

---

## Diff results (Step 3 — byte-identity gate)

```
OK: hcdp_raster.py
OK: hcdp_raster_cli.py
OK: ingest.py
OK: backfill.sh
OK: run.sh
```

All 5 files byte-identical between `/opt/hcdp/` (live) and `/opt/hcdp/src/services/jetstream2/` (vendored). No one edited the host copies in the ~26-hour window between vendoring (commit `d7a753f`, 2026-06-10 ~22:08 UTC) and the Phase 2 swap.

---

## Swap (Step 4)

5 files moved to `*.pre-vendor`, replaced with symlinks pointing into the checkout:

| Symlink | → Target |
|---|---|
| `/opt/hcdp/hcdp_raster.py` | `/opt/hcdp/src/services/jetstream2/hcdp_raster.py` |
| `/opt/hcdp/hcdp_raster_cli.py` | `…/hcdp_raster_cli.py` |
| `/opt/hcdp/ingest.py` | `…/ingest.py` |
| `/opt/hcdp/backfill.sh` | `…/backfill.sh` |
| `/opt/hcdp/run.sh` | `…/run.sh` |

`*.pre-vendor` backups preserved at original paths (sizes 30,854 / 3,402 / 22,201 / 3,173 / 135 B respectively).

### Exec-bit verification through symlink (`ls -lL`)

```
-rwxrwxr-x  3173 backfill.sh           ← exec preserved
-rw-rw-r-- 30854 hcdp_raster.py        ← module file, no exec needed
-rwxrwxr-x  3402 hcdp_raster_cli.py    ← exec preserved
-rw-rw-r-- 22201 ingest.py             ← module file, no exec needed
-rwxrwxr-x   135 run.sh                ← exec preserved (critical: cron needs this)
```

`bash -n /opt/hcdp/run.sh` and `bash -n /opt/hcdp/backfill.sh` both pass syntax check through the symlink.

---

## Post-swap end-to-end verification (Step 5)

Manual `run.sh --update` runs the full cron-path stack: shell follows `run.sh` symlink → sources `/opt/hcdp/.env` → execs `/opt/hcdp/venv/bin/python /opt/hcdp/ingest.py` (also a symlink) → imports `psycopg2` → connects to local Postgres → upserts.

```
$ /opt/hcdp/run.sh --update
Incremental update from 2026-06-10T23:50:00...
  Fetched 34 measurements (offset=0, total so far=34)
  Upserted 34 measurements
Fetching station monitor...
  Upserted 76 station monitor records
```

The 34-row fetch (smaller than typical 10–11k) is expected: the cron tick at 23:35 already pulled the previous 15-minute window, so this manual run only sees the partial-window delta of the past ~30 min.

### `ingestion_log` row from the manual run

```
  id  |        started_utc         | job_type | status  | error 
------+----------------------------+----------+---------+-------
 7077 | 2026-06-11 00:05:20.615003 | update   | success |       
```

Row 7077 confirms the symlinked path wrote to the database successfully end-to-end. No error message, status `success`. Why this is the gate that matters: it proves `run.sh.sh-symlink → ingest.py-symlink → live database` actually works as an integrated pipeline, not just that the files resolve.

---

## Commit pushed

Branch: `claude/integrate-pipeline-codex-OMPo2` (private `hcdp-ai-interface`).

| Hash | Message | Files |
|------|---------|-------|
| **`c3c790a`** | Mark Phase 2 complete: data-layer symlinks live | `services/jetstream2/README.md` (+9 / −5) |

The README change ticks the Phase 2 checkbox with the completion details inline (date, what was verified). Both phases of the migration plan in the README are now `[x]`.

---

## State after Phase 2

```
/opt/hcdp/                          (host code now fully symlinked)
├── hcdp_raster.py        → /opt/hcdp/src/services/jetstream2/hcdp_raster.py
├── hcdp_raster_cli.py    → …/hcdp_raster_cli.py
├── ingest.py             → …/ingest.py
├── backfill.sh           → …/backfill.sh
├── run.sh                → …/run.sh
├── *.pre-vendor          (5 backups, untouched)
├── .env                  (real file, on-host only)
├── raster_service/
│   ├── auth.py           → …/raster_service/auth.py
│   ├── main.py           → …/raster_service/main.py
│   ├── overlay.py        → …/raster_service/overlay.py
│   ├── routes.py         → …/raster_service/routes.py
│   ├── requirements.txt  → …/raster_service/requirements.txt
│   ├── *.pre-vendor      (5 backups, untouched)
│   ├── .env              (real file)
│   ├── .venv             (real dir)
│   └── service.log       (real file)
└── …                     (logs, data/, mcp/, etc. — out of scope for this migration)
```

Update flow for the host going forward (from the README):
```
cd /opt/hcdp/src && git pull --ff-only
sudo systemctl restart hcdp-raster-service   # only when raster_service/ code changed
# cron auto-picks-up data-layer changes on the next quarter-hour tick
```

The next regular cron `--update` tick fires at 2026-06-11 00:15 UTC and will also write to `ingestion_log` from the symlinked path — additional passive verification will accumulate without further action.

---

## Carry-over from the Phase-1 report — still open

The DB password rotation checklist surfaced during Phase 1 has not been addressed in this session (rotation is coordinated from the laptop side per your instruction). Items still outstanding:
- Rotate the postgres role password
- Update `/opt/hcdp/.env`, `/opt/hcdp/raster_service/.env`, laptop chatbot `.env`
- Redact `/opt/hcdp/SCHEMA_CONTEXT.md` line 8
- Consider tightening `pg_hba.conf` line `host hcdp postgres 0.0.0.0/0 scram-sha-256` to a CIDR

No part of Phase 2 changes the urgency or scope of this carry-over.
