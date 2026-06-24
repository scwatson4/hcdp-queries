# Backfill mesonet_stations.island for the 'Unknown' rows (gated DB write)

**Date:** 2026-06-24
**Scope:** authorized, gated database write. Derived each `island='Unknown'` station's island from
its coordinates via the PostGIS `hawaii_islands` polygons, then updated ONLY the `island` column of
those rows in a single transaction. No other column, row, table, schema, service, or firewall
change. No secrets in this document.

---

## Phase 1 — read-only derivation (proposed, then approved)

8 `Unknown` rows. Each was matched to its nearest `hawaii_islands` polygon; all 8 fell **inside**
their polygon with `dist_m = 0` → all CONFIDENT, none flagged. `island_name` (ʻokina) was mapped to
the plain-ASCII form `mesonet_stations` uses (Hawaiʻi→Hawaii, Molokaʻi→Molokai).

| station_id | name | lat / lng | poly (ʻokina) | → ASCII | inside_polygon | dist_m | confidence |
|---|---|---|---|---|---|---|---|
| 0231 | Kaiholena | 19.169 / −155.570 | Hawaiʻi | Hawaii | true | 0 | CONFIDENT |
| 0232 | Kahilipalinui | 19.044 / −155.579 | Hawaiʻi | Hawaii | true | 0 | CONFIDENT |
| 0233 | Ka Lae | 18.953 / −155.689 | Hawaiʻi | Hawaii | true | 0 | CONFIDENT |
| 0234 | Kahuku | 19.053 / −155.692 | Hawaiʻi | Hawaii | true | 0 | CONFIDENT |
| 0235 | Manukā | 19.059 / −155.852 | Hawaiʻi | Hawaii | true | 0 | CONFIDENT |
| 0243 | Kona Hema | 19.207 / −155.811 | Hawaiʻi | Hawaii | true | 0 | CONFIDENT |
| 0247 | Kipahoehoe | 19.231 / −155.868 | Hawaiʻi | Hawaii | true | 0 | CONFIDENT |
| 0411 | Keōpukaloa | 21.145 / −156.729 | Molokaʻi | Molokai | true | 0 | CONFIDENT |

Sanity checks held: **Manukā (0235) → Hawaii**, **Keōpukaloa (0411) → Molokai**. The 7 Hawaii
stations are the contiguous south Kona/Kaʻū cluster (Ka Lae = South Point). Approved by the user.

## Phase 2 — transactional write (COMMITTED)

Single transaction, each `UPDATE` guarded with `AND island = 'Unknown'`, verified in-transaction and
again on a fresh post-commit connection:

```sql
BEGIN;
UPDATE mesonet_stations SET island='Hawaii'
  WHERE island='Unknown' AND station_id IN ('0231','0232','0233','0234','0235','0243','0247');  -- UPDATE 7
UPDATE mesonet_stations SET island='Molokai'
  WHERE island='Unknown' AND station_id='0411';                                                 -- UPDATE 1
-- in-transaction guard: hawaii_ok=7, molokai_ok=1, unknown_left=0
COMMIT;
```

**Rows changed: 8** (7 → Hawaii, 1 → Molokai). **`still_unknown = 0`.**

### Final mapping (post-commit, fresh connection)

| station_id | name | island |
|---|---|---|
| 0231 | Kaiholena | Hawaii |
| 0232 | Kahilipalinui | Hawaii |
| 0233 | Ka Lae | Hawaii |
| 0234 | Kahuku | Hawaii |
| 0235 | Manukā | Hawaii |
| 0243 | Kona Hema | Hawaii |
| 0247 | Kipahoehoe | Hawaii |
| 0411 | Keōpukaloa | Molokai |

### Post-update island distribution (sanity — no stray values introduced)

`Hawaii 44 · Kauai 10 · Maui 26 · Molokai 7 · Oahu 15 · (blank) 1`

## Out-of-scope item flagged (not changed)

One row carries a blank island that is **not** `'Unknown'` and so was correctly outside this task's
scope: station **0520 "Kaʻala Repeater"**, `island = NULL` **and `lat/lng = NULL`**. Because it has
no coordinates, the PostGIS derivation can't resolve it (by name, Mount Kaʻala is on Oʻahu, but
that's a manual call, not a coordinate derivation). Left untouched; needs a separate authorization
and a non-coordinate source to set.

## Verdict
COMMIT. 8 `'Unknown'` rows backfilled (7 Hawaii, 1 Molokai); 0 Unknown remaining; only the `island`
column touched. One unrelated NULL-island/NULL-coordinate row (0520) remains, flagged for a separate
decision.

## Provenance
HCDP Postgres `mesonet_stations` + `hawaii_islands` (PostGIS polygons, `island_name` in ʻokina form).
Write performed as a single guarded transaction with before/after verification.
