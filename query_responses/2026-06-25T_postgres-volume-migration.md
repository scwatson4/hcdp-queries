# Migrate the Postgres data directory to the larger second volume (original kept as fallback)

**Date:** 2026-06-25
**Scope:** authorized migration of the PostgreSQL data directory from the near-full volume to the
large, empty second volume, keeping the original copy intact as a fallback. Required a brief
Postgres stop. No schema/data-row edits, no firewall/security-group/ufw change, no raster/VNC
change, no secrets printed.

---

## Result — COMPLETE ✅

PostgreSQL now runs from the second volume, with **535 GB free** (was 44 GB), the temp-spill /
materialized-view-refresh pressure resolved, and the **original copy preserved on `/dev/sdc`**.

| | Before | After |
|---|---|---|
| Data directory | `/media/volume/hcdp_postgres_db/postgresql/16/main` (`/dev/sdc`) | `/media/volume/hcdp_postgres_db_2/postgresql/16/main` (`/dev/sdb`) |
| Volume free | 44 G of 246 G (83% full) | **535 G of 738 G (28% used)** |
| Downtime | — | **180 s (3 min)** |

## Method — two-pass copy to minimize downtime

1. **Pass 1 (online, zero downtime):** `rsync -aHAX --numeric-ids` of the 202 GB data dir to
   `/dev/sdb` while Postgres stayed **up and serving** (produces a "fuzzy" copy).
2. **Config backups:** `postgresql.conf` and the systemd `wait-for-volume.conf` drop-in copied to
   timestamped `.bak` (rollback path).
3. **Cutover (the 3-min downtime):**
   - `systemctl stop postgresql@16-main`
   - **Pass-2 delta `rsync`** (Postgres stopped → consistent copy)
   - Repoint `data_directory` in `/etc/postgresql/16/main/postgresql.conf` → new path
   - Repoint the reboot drop-in `RequiresMountsFor` → `/media/volume/hcdp_postgres_db_2`
   - `systemctl daemon-reload && systemctl start postgresql@16-main`
4. **Original left untouched** on `/dev/sdc` (read-only throughout) as the fallback.

## Verification (post-cutover)

| Check | Result |
|---|---|
| Physical device | `/dev/sdb`, 535 G free |
| Startup log | clean — *"database system was shut down … ready to accept connections"*; no recovery/corruption |
| Stations | 104 |
| Measurements | 1,035,036,453 (~1.03 B); latest `2026-06-25 02:25` (current) |
| Station 0533 | 221,262 raw rows + 15 in `mv_daily_station_summary_qc` |
| Ingest cron | jobs 8476–8478 all `success` — ingest flowing after restart |
| Original copy | intact on `/dev/sdc` (202 G), untouched |
| Reboot resilience | drop-in repointed to the new mount; survives reboot |

## What this fixes
`pgsql_tmp` (the temp-spill that exhausted disk during a concurrent MV refresh on 2026-06-25) now
lives inside PGDATA on `/dev/sdb` with **535 GB free** — a full `REFRESH MATERIALIZED VIEW`, even
concurrently with the cron, now has ample space. The earlier "No space left on device" failure mode
is resolved.

## Rollback (if ever needed)
The original data dir is untouched on `/dev/sdc`, and both config files have `.bak` copies. To
revert: restore the two `.bak` files (`data_directory` + drop-in), `daemon-reload`, and start —
Postgres comes back up on the original `/dev/sdc` copy.

## Follow-ups (not actioned)
- **Reclaiming `/dev/sdc`:** once you're confident in the migration, the 202 GB original copy can be
  removed to free that volume — left in place per "keep the original copy just in case."
- **Incidental security note (pre-existing, NOT changed):** the PG log shows internet scanners
  hitting port 5432 from random IPs, correctly rejected by `pg_hba.conf`. The DB isn't compromised,
  but 5432 is reachable from the internet (ufw allows it). Worth tightening; left alone per the
  standing "don't touch 5432 exposure" constraint.

## Provenance
Source `/dev/sdc` data dir (`SHOW data_directory`), target `/dev/sdb`. Verified via `df`,
`pg_isready`, the PG server log, and row-count/freshness SELECTs against `mesonet_stations`,
`mesonet_measurements`, `mv_daily_station_summary_qc`, `ingestion_log`. Two-pass `rsync`; cutover
downtime 180 s; original copy and timestamped config backups retained.
