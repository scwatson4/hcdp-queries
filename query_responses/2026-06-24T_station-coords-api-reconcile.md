# Reconcile the 8 backfilled stations' coordinates: DB vs live HCDP API

**Date:** 2026-06-24
**Scope:** read-only. Printed exact (unrounded) coordinates for the 8 stations whose `island` was
just backfilled, then compared them against the live HCDP API. No database/service/firewall/data
changes. No secrets in this document (API token sourced from `/opt/hcdp/.env` and never printed).

---

## 1. Exact coordinates from `mesonet_stations`

| station_id | name | lat | lng | island |
|---|---|---|---|---|
| 0231 | Kaiholena | 19.16877 | −155.57035 | Hawaii |
| 0232 | Kahilipalinui | 19.044023 | −155.57921 | Hawaii |
| 0233 | Ka Lae | 18.953 | −155.689 | Hawaii |
| 0234 | Kahuku | 19.052519 | −155.69205 | Hawaii |
| 0235 | Manukā | 19.05934 | −155.852 | Hawaii |
| 0243 | Kona Hema | 19.2068247 | −155.8109802 | Hawaii |
| 0247 | Kipahoehoe | 19.2312376 | −155.8681021 | Hawaii |
| 0411 | Keōpukaloa | 21.145283 | −156.729459 | Molokai |

## 2. Live HCDP API reconciliation

Queried `GET https://api.hcdp.ikewai.org/mesonet/db/stations?location=hawaii&row_mode=json`
(Bearer auth; 104 stations returned), matched on `station_id`, and computed the haversine distance
between the DB coordinate and the API coordinate:

| station_id | name | DB lat / lng | API lat / lng | Δ (m) | API status |
|---|---|---|---|---|---|
| 0231 | Kaiholena | 19.168770 / −155.570350 | 19.168770 / −155.570350 | 0.0 | active |
| 0232 | Kahilipalinui | 19.044023 / −155.579210 | 19.044023 / −155.579210 | 0.0 | planned |
| 0233 | Ka Lae | 18.953000 / −155.689000 | 18.953000 / −155.689000 | 0.0 | planned |
| 0234 | Kahuku | 19.052519 / −155.692050 | 19.052519 / −155.692050 | 0.0 | planned |
| 0235 | Manukā | 19.059340 / −155.852000 | 19.059340 / −155.852000 | 0.0 | active |
| 0243 | Kona Hema | 19.206825 / −155.810980 | 19.206825 / −155.810980 | 0.0 | active |
| 0247 | Kipahoehoe | 19.231238 / −155.868102 | 19.231238 / −155.868102 | 0.0 | planned |
| 0411 | Keōpukaloa | 21.145283 / −156.729459 | 21.145283 / −156.729459 | 0.0 | active |

**All 8 match the live API exactly — Δ = 0.0 m on every station**, same precision and values. The
DB's stored coordinates are authoritative and current; no drift. The island assignments from the
coordinate-based backfill (7 Hawaii, 1 Molokai) therefore rest on solid coordinates.

## Useful detail: the API `status` field (not stored in the DB)

Four of these stations are **`planned`**, not yet `active`:

- **active:** 0231 Kaiholena, 0235 Manukā, 0243 Kona Hema, 0411 Keōpukaloa
- **planned:** 0232 Kahilipalinui, 0233 Ka Lae, 0234 Kahuku, 0247 Kipahoehoe

This likely explains *why* these rows arrived as `island='Unknown'` — planned / newly-registered
stations that came in with coordinates but incomplete metadata. The coordinates are solid, so the
Hawaii/Molokai assignments stand. Whether to ingest `status` into `mesonet_stations` is a separate,
authorized change.

## Provenance
Coordinates: `mesonet_stations` (read-only `psql`). API: live
`GET /mesonet/db/stations?location=hawaii&row_mode=json` against `HCDP_API_BASE`, Bearer token
sourced from `/opt/hcdp/.env` (never printed). Distances by haversine. Read-only throughout.
