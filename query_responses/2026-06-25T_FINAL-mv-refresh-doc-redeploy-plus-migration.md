# Final report: manual MV refresh + agent-doc redeploy (with the volume-migration recap folded in)

**Date:** 2026-06-25
**Scope:** two scoped, authorized tasks executed back-to-back — (1) a database-only manual refresh
of the QC views, and (2) a repo-only checkout of three agent docs — plus a recap of the preceding
Postgres volume migration. No firewall/security-group/ufw/VNC change; no secrets printed.

---

## Prompt 1 — manual QC-view refresh (database-only)

**Before counts (0533):** daily **15**, monthly **1** — already present (the earlier 6-hourly cron
refresh had picked 0533 up). So this run re-validated rather than first-introduced it.

**Refresh (both `CONCURRENTLY`, no fallback needed):**

| view | result | wall-clock |
|---|---|---|
| `mv_daily_station_summary_qc` | `REFRESH MATERIALIZED VIEW` | **14:37** |
| `mv_monthly_station_summary_qc` | `REFRESH MATERIALIZED VIEW` | **0.32 s** |

**After counts (0533):** daily **15** (`2026-06-10` → `2026-06-24`), monthly **1**. Unchanged from
before (0533 was already in), as expected.

**The headline: this validated the migration.** This is the *same* refresh that died at ~5 minutes
with `No space left on device` on the old volume. Post-migration it ran to completion — `pgsql_tmp`
peaked at **~61 GB** (larger than the entire 44 GB that was ever free on the old `/dev/sdc`), then
was **reclaimed to 4 KB** on completion, leaving `/dev/sdb` at 535 GB free. The 60+ GB is transient
sort/spill from re-aggregating ~1.03 B `mesonet_measurements` rows under an 8 MB `work_mem` — not
missing data (0533 is 15 of 74,620 rows). See the companion explainer report for the full mechanics.

## Prompt 2 — redeploy three agent docs (repo-only checkout)

**Step 1 (status check):** `CLAUDE.md` and `response_style.md` showed staged-modified (`M `);
`AGENTS.md` clean. Verified these were **not hand-edits** — both exactly matched the qgis-glue commit
they were last overlaid from (`7748790`), i.e. clean prior `git checkout` overlays with no local
work to clobber. Proceeded.

**Step 2:** `git checkout origin/qgis-glue --` the three files.

**Step 3 — `diff --stat`:**
```
 jetstream2/AGENTS.md                         | 15 +++++--
 jetstream2/CLAUDE.md                         | 34 ++++++++++++++
 jetstream2/agent_reference/response_style.md | 67 ++++++++++++++++++++++++++++
 3 files changed, 112 insertions(+), 4 deletions(-)
```
All three now `MATCH origin/qgis-glue`. The new-rule greps all matched:
- `CLAUDE.md` — "Forecasts/predictions get a one-line disclaimer" (L57), "Don't narrate the machinery" (L64)
- `response_style.md` — "live narration and status lines" (L45), "Forecasts and predictions — lead with a one-line disclaimer" (L72)
- `AGENTS.md` — "No process narration, and never name the machinery" (L26), "Forecasts get a disclaimer" (L32)

No commit, no push, no branch switch, no other files, no restart — docs are re-read at runtime, so
they take effect on the next query.

---

## Recap — Postgres data-volume migration (the change that enabled Prompt 1 to succeed)

Migrated the PostgreSQL data directory off the near-full volume onto the large empty one, original
kept as a fallback.

| | Before | After |
|---|---|---|
| Data directory | `…/hcdp_postgres_db/postgresql/16/main` (`/dev/sdc`) | `…/hcdp_postgres_db_2/postgresql/16/main` (`/dev/sdb`) |
| Volume free | 44 G of 246 G (83% full) | **535 G of 738 G (28% used)** |
| Downtime | — | **180 s (3 min)** |

- **Method:** two-pass `rsync` — 202 GB copied online (zero downtime) while Postgres stayed up, then
  a brief stop for a consistent delta-sync + cutover (repoint `data_directory` in
  `postgresql.conf`, repoint the `RequiresMountsFor` reboot drop-in), restart.
- **Verified:** clean startup (no recovery/corruption); 104 stations; ~1.03 B measurements current;
  station 0533 present; ingest cron back to `success`; reboot drop-in repointed (survives reboot).
- **Fallback preserved:** original 202 GB copy untouched on `/dev/sdc`; both config files have
  timestamped `.bak` copies. Rollback = restore the two `.bak`s, reload, start.
- **Fixes:** `pgsql_tmp` now lives on `/dev/sdb` with ample headroom, so MV refreshes no longer hit
  `No space left on device` (proven by Prompt 1 above).

### Standing follow-ups (not actioned)
- **Reclaim `/dev/sdc`:** the 202 GB original copy can be removed once you're confident — left in
  place per "keep the original copy just in case."
- **Security (pre-existing, NOT changed):** PG log shows internet scanners hitting `5432`, correctly
  rejected by `pg_hba.conf`. The DB isn't compromised, but `5432` is internet-reachable (ufw allows
  it). Worth tightening; left alone per the standing "don't touch 5432 exposure" constraint.
- **Refresh efficiency:** the manual refresh used the default 8 MB `work_mem`; the cron uses 4 GB
  (far less spill). A session `SET work_mem='4GB'` would shrink manual-refresh temp usage — optional,
  unnecessary now that there's 535 GB free.

## Provenance
DB: `mv_daily_station_summary_qc`, `mv_monthly_station_summary_qc`, `mesonet_measurements`,
`mesonet_stations`, `ingestion_log`, `pg_stat_activity`. Repo: `/opt/hcdp/src` checkout of
`hcdp-ai-interface@qgis-glue` (3 docs). Migration verified via `df`, the PG server log, and
row-count/freshness SELECTs. All read-only except the two authorized `REFRESH` statements and the
three-file `git checkout`.
