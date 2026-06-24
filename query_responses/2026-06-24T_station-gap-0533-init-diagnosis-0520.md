# Close the 103-vs-104 station gap (0533), diagnose the failed `--init`, and set station 0520

**Date:** 2026-06-24
**Scope:** three authorized items. (A) add the missing station 0533; (B) read-only diagnosis of why
the April `--init` jobs failed; plus a (separate, standalone) one-row fix to station 0520. Each DB
write was its own guarded transaction. No materialized-view refresh, no schema/index/service/
firewall change, no secrets (API token sourced from `/opt/hcdp/.env`, never printed).

---

## A. The 103-vs-104 gap = station 0533, a new active station never ingested

The one station in the API but not the DB is **0533 "Maunawili Pālāwai"** (windward Oʻahu, Kailua
side; 21.36827, −157.76272; elev 14 m; nws_id 078HI; skn 790.12). The reverse check (DB rows not in
the API) was clean — the gap is exactly this one station.

- **Still active?** Yes — API `status = active`, and **reporting now**: 219,876 measurements,
  earliest 2026-06-10, latest 2026-06-24 (today).
- **Added recently?** Yes — first data 2026-06-10 (~2 weeks ago); a newly commissioned station.
- **Why it was missing:** `ingest_stations()` runs only on `--init`; the 15-min `--update` cron
  ingests *measurements* but never station metadata. So 0533's measurements flowed in while its
  metadata row was never created — and because the QC views join to `mesonet_stations`, **0533 had
  0 rows in `mv_daily_station_summary_qc`**, i.e. an active station was invisible to every ranking,
  map, and the station list despite collecting data.

**Fix (Task A) — guarded insert, COMMITTED:**
```
INSERT INTO mesonet_stations (..., island, location, status, raw_metadata, geom, updated_at)
VALUES ('0533','Maunawili Pālāwai',21.36827,-157.76272,14,'Oahu','hawaii','active', <api json>,
        ST_SetSRID(ST_MakePoint(-157.76272,21.36827),4326), now())
ON CONFLICT (station_id) DO NOTHING;     -- INSERT 0 1
```
Island `Oahu` confirmed inside the `hawaii_islands` polygon. **No MV refresh performed** (flagged
sensitivity); 0533's 2 weeks of data will surface in the QC views at the next scheduled 6-hourly
`--refresh-views` cron.

## B. Why the April `--init` jobs errored (read-only diagnosis)

The only two `init` jobs in `ingestion_log`, both 2026-04-02, both failed:

| id | started | finished | error |
|---|---|---|---|
| 1 | 06:33 | 09:54 (~3.4 h) | `Process crashed - no error captured` |
| 5 | 10:10 | 10:21 | `Killed - OOM risk, switching to chunked backfill` |

`--init` (`cmd_init`) does a memory-heavy 7-day measurement backfill; it **OOM-crashed**, and the
pipeline switched to the chunked 15-min `--update` path. That path has run cleanly ever since
(job 8466 and counting, all `success`) — but it **never calls `ingest_stations()`**, which is the
systemic reason any station added after the last successful station-load (e.g. 0533) goes missing.

**Recommendation (not actioned):** don't re-run the OOM-prone full `--init`. Instead run
`ingest_stations()` standalone periodically (it only hits the lightweight stations endpoint, no
measurement backfill) or add a stations refresh to cron, so new stations are picked up
automatically. The Part B `ingest.py` change (commit `b3fd7bc`) already makes such a run populate
`status` + island correctly.

## Standalone change — station 0520 ("Kaʻala Repeater")

Executed exactly to the authorized scope: one row, only if `island` was NULL, coordinates filled
only if NULL (via `COALESCE`), single transaction, assert-or-rollback.

- **Before:** `0520 | Kaʻala Repeater | lat NULL | lng NULL | island NULL` → matches expectation, proceeded.
- **Write:** `UPDATE 1` (guarded `WHERE station_id='0520' AND island IS NULL`).
- **After:** `0520 | Kaʻala Repeater | 21.509 | −158.147 | Oahu` (Mount Kaʻala, Oʻahu's summit).
- **`blank_or_unknown` = 0**; in-transaction guard passed → **COMMIT**.

(0520's `status` reads `inactive`, set by the earlier status backfill — consistent with a
coordinate-less repeater entry.)

## Final integrity (fresh connection)

| metric | value |
|---|---|
| total `mesonet_stations` rows | **104** (was 103; +1 for 0533) — now matches the API's 104 |
| `island IS NULL OR 'Unknown'` | **0** |
| island distribution | Hawaii 44 · Kauai 10 · Maui 26 · Molokai 7 · **Oahu 17** (+2: 0520, 0533) |

The 103-vs-104 gap is closed and every station now has a real island.

## Provenance
DB: `mesonet_stations`, `mv_daily_station_summary_qc`, `mesonet_measurements`, `ingestion_log`,
`hawaii_islands`. API: live `GET /mesonet/db/stations` (Bearer token from `/opt/hcdp/.env`, never
printed). Three separate guarded transactions; 0520 done strictly to its standalone authorized
scope. No MV refresh, no schema/service/firewall change.
