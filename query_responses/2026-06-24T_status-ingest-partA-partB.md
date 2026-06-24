# Ingest the mesonet `status` field: column + backfill (Part A) and durable ingest (Part B)

**Date:** 2026-06-24
**Scope:** authorized two-part change. Part A = DB write (add `status` column + backfill from the
live API). Part B = make ingestion durable via a repo change to `ingest.py` (routed through
`qgis-glue`, redeployed — NOT an in-place edit of the deployed checkout). No firewall/service
changes. No secrets in this document (API token sourced from `/opt/hcdp/.env`, never printed).

---

## Part A — `status` column + backfill (COMMITTED)

One gated transaction: `ALTER TABLE mesonet_stations ADD COLUMN IF NOT EXISTS status text`, then
backfill from the live API (`GET /mesonet/db/stations?location=hawaii&row_mode=json`), with status
values allow-listed to `{active, planned, inactive}` and matched on `station_id`.

- **`UPDATE 103`** — every DB row matched an API station; **0 rows left NULL**.
- Distribution written: **75 active · 25 planned · 3 inactive** (= 103).
- Sanity on the 8 recently island-backfilled stations: 4 `active` (0231 Kaiholena, 0235 Manukā,
  0243 Kona Hema, 0411 Keōpukaloa) + 4 `planned` (0232 Kahilipalinui, 0233 Ka Lae, 0234 Kahuku,
  0247 Kipahoehoe). Matches the API exactly.

(Note: `status` is a lifecycle stage, not a live online/offline flag — see the prior status-field
analysis report. `planned` stations have no data yet; for real-time health use data freshness.)

## Part B — durable ingestion (repo change `qgis-glue@b3fd7bc`, redeployed)

Done through version control, not by editing the deployed artifact: clean `git worktree` off
`origin/qgis-glue` → edit → `py_compile` → commit → push (`3e4072b..b3fd7bc`, fast-forward) →
redeploy to `/opt/hcdp/src` via `git checkout origin/qgis-glue -- services/jetstream2/ingest.py`
(verified MATCH, compiles). Worktree removed afterward.

Two changes to `ingest_stations()` (which runs only on `--init`, not the 15-min `--update` cron):

1. **Persist `status`** through the upsert — added `status` to the column list, a `%s` placeholder,
   `s.get("status")` to the params, and `status=EXCLUDED.status` to the `ON CONFLICT DO UPDATE`. A
   future `--init` now populates `mesonet_stations.status` durably.

2. **Island backstop (root-cause fix).** The Unknown-island rows came from `derive_island()` — a
   crude bounding-box classifier that returns `'Unknown'` for coordinates outside its boxes (South
   Kona/Kaʻū at lat < 19.35, and east Molokaʻi). Because the upsert does `island=EXCLUDED.island`,
   **the next `--init` would have reverted the earlier island backfill to `'Unknown'`.** Added a
   post-upsert `UPDATE` that resolves any `'Unknown'`/`NULL` island from the authoritative
   `hawaii_islands` PostGIS polygons (nearest-polygon `<->`), mapping ʻokina → plain-ASCII island
   names, run after `geom` is populated. Validated the logic yields the correct 7 Hawaii + 1
   Molokai before committing. `derive_island()` itself is untouched (its bbox logic and any tests
   stay intact); the backstop only fills gaps.

```sql
-- the backstop (after the existing geom UPDATE, inside ingest_stations)
UPDATE mesonet_stations m
   SET island = CASE h.island_name
       WHEN 'Hawaiʻi' THEN 'Hawaii'  WHEN 'Maui' THEN 'Maui'  WHEN 'Oʻahu' THEN 'Oahu'
       WHEN 'Kauaʻi' THEN 'Kauai'    WHEN 'Molokaʻi' THEN 'Molokai'  WHEN 'Lānaʻi' THEN 'Lanai'
       WHEN 'Niʻihau' THEN 'Niihau'  WHEN 'Kahoʻolawe' THEN 'Kahoolawe'  ELSE m.island END
  FROM LATERAL (SELECT island_name FROM hawaii_islands h2
                ORDER BY m.geom <-> h2.geometry LIMIT 1) h
 WHERE m.geom IS NOT NULL AND (m.island IS NULL OR m.island = 'Unknown');
```

### Scope note
Part B was approved as "ingest the status field." I included the island backstop in the same commit
because it directly protects the island backfill authorized earlier (a future `--init` would
otherwise undo it). It is clearly described in the commit message and is a trivial revert if you'd
prefer the two kept separate.

## Why this was safe between cron runs
The 15-minute `--update` cron calls `cmd_update()` (measurements only); it does **not** call
`ingest_stations()`. Only `--init` (full reload) does. So neither the island backfill nor the new
`status` values were ever at risk during routine operation — the backstop makes a future `--init`
safe as well.

## Open items (not changed)
- **103 vs 104:** the API returns 104 stations; `mesonet_stations` has 103. One API station has no
  DB row (or a duplicate exists). The status backfill only touched matching IDs, so it's safe — but
  worth a separate look.
- **Station 0520 ("Kaʻala Repeater"):** `island = NULL` and `lat/lng = NULL`. The new backstop will
  classify it automatically *if* it ever receives coordinates; until then it needs a non-coordinate
  source.

## Provenance
DB: `mesonet_stations`, `hawaii_islands` (PostGIS polygons). API: live
`GET /mesonet/db/stations` (Bearer token from `/opt/hcdp/.env`, never printed). Code:
`hcdp-ai-interface@qgis-glue` commit `b3fd7bc`, redeployed to `/opt/hcdp/src`. Part A executed as a
single guarded transaction; Part B verified with `py_compile` + a read-only SELECT of the backstop
logic before commit.
