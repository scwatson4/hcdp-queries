# Ingesting the mesonet `status` field: what it means + gated plan

**Date:** 2026-06-24
**Scope:** read-only analysis (live HCDP API + DB freshness cross-check) to characterize the
station `status` field before ingesting it, plus a gated proposal for adding it to
`mesonet_stations`. **No schema/data/code change made** — this stops for approval. No secrets
(API token sourced from `/opt/hcdp/.env`, never printed).

---

## The question

After reconciling the 8 backfilled stations against the API, the `status` field surfaced. The ask:
"ingest the `status` field — I assume that tells us if the station is online or not?"

## Finding: `status` is a lifecycle stage, NOT a live online/offline flag

Across all 104 API stations, `status` takes **three** values. Cross-checked against actual data
freshness (`MAX(timestamp)` in `mesonet_measurements`):

| status | count | meaning | the 8 backfilled stations | data freshness |
|---|---|---|---|---|
| `active` | 76 | commissioned & reporting | 0231, 0235, 0243, 0411 | all **fresh** (read today) |
| `planned` | 25 | registered w/ coords, not yet deployed | 0232, 0233, 0234, 0247 | all **no data at all** |
| `inactive` | 3 | decommissioned / retired | — | — |

So `status` is a **commissioning/lifecycle stage**, not real-time connectivity. It cleanly explains
the earlier `island='Unknown'` rows: 4 of the 8 are `planned` — coordinates registered but the
station never reported, hence incomplete metadata.

**Important caveat:** `status` will NOT flag an `active` station that has gone offline due to a
fault — it still reads `active` while silent. The authoritative "reporting right now" signal is
**data freshness** (last reading age), not `status`. Most useful is the pair: `status` (commissioned?)
+ freshness (reporting now?).

## Gated plan (nothing executed yet)

**Part A — DB write (one transaction, on approval):**
```sql
ALTER TABLE mesonet_stations ADD COLUMN status text;   -- nullable, no default
-- backfill all matching station_ids from the live API:
--   UPDATE mesonet_stations SET status = '<api status>' WHERE station_id = '<id>';
-- expected distribution: 76 active + 25 planned + 3 inactive
```

**Part B — durability (route through the repo, NOT an in-place edit):** for `status` to stay current
on the 15-minute cron ingest, `ingest_stations()` in `services/jetstream2/ingest.py` must add
`status` to its upsert. That's a code change through `qgis-glue` + redeploy — not an edit to the
deployed `/opt/hcdp/src` checkout (same drift lesson as the agent docs). Without Part B, the column
holds today's backfilled values but won't refresh on future ingests.

## Flag: station-count discrepancy (separate item)

The live API returns **104** stations; `mesonet_stations` has **103** rows — one station is in the
API but not the DB (or a duplicate exists). The status backfill only touches matching IDs, so it's
safe, but the 103-vs-104 gap is worth a separate look.

## Recommendation

Add `status` (it's genuinely useful — it would let station rankings exclude `planned`/`inactive`
sites and explains the Unknown-island rows). But because it is not a live online/offline flag,
consider pairing it with a derived "currently reporting" signal from freshness if the goal is
real-time station health. Proceed with Part A on approval; do Part B as a reviewed repo change.

## Provenance
Live `GET /mesonet/db/stations?location=hawaii&row_mode=json` (Bearer token from `/opt/hcdp/.env`,
never printed); freshness from `mesonet_measurements`; counts from `mesonet_stations`. Read-only.
