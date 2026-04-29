# Query: Do you have access to the HCDP API documentation? Can you explain what endpoints are currently being used by this SQL database?

**Date:** 2026-04-29

---

Yes, the API spec is at `/opt/hcdp/hcdp_api.yaml`. Here's the full picture:

## All HCDP API endpoints

| Endpoint | Tag | What it does |
|----------|-----|-------------|
| `/mesonet/db/measurements` | mesonet | 5-min station measurements |
| `/mesonet/db/stations` | mesonet | Station metadata |
| `/mesonet/db/variables` | mesonet | Variable definitions |
| `/mesonet/db/stationMonitor` | mesonet | Latest station health snapshot |
| `/mesonet/db/measurements/email` | mesonet | Email delivery of large measurement exports |
| `/stations` | stations | Historical station values (MongoDB-style query) |
| `/raster` | raster | GeoTIFF gridded maps (rainfall, temperature, SPI) |
| `/raster/timeseries` | raster | Point time series extracted from rasters at a lat/lng |
| `/genzip/email` | genzip | Email a zip of bulk data |
| `/genzip/instant/content` | genzip | Instant zip download (content) |
| `/genzip/instant/link` | genzip | Instant zip download (link) |
| `/genzip/instant/splitlink` | genzip | Split zip download |
| `/files/production/list` | files | List production files available |
| `/files/production/retrieve` | files | Download production files |

## What our database uses (4 of 14 endpoints)

| Endpoint | → DB Table | How used |
|----------|-----------|----------|
| **`/mesonet/db/measurements`** | `mesonet_measurements` | Cron every 15 min (incremental) + full backfill 2022-present |
| **`/mesonet/db/stations`** | `mesonet_stations` | One-time load + periodic refresh |
| **`/mesonet/db/variables`** | `mesonet_variables` | One-time load |
| **`/stations`** | `historical_station_values` | Backfill 1990-present (monthly rainfall + temperature) |

Plus `/mesonet/db/stationMonitor` → `station_monitor` (health snapshot, not used for analysis).

## What we're NOT using (10 endpoints)

| Endpoint | What we're missing | Value if ingested |
|----------|-------------------|-------------------|
| **`/raster`** | Gridded rainfall/temperature/SPI maps (GeoTIFF) | Spatial interpolation independent of station locations. Would give better areal rainfall estimates and drought index. |
| **`/raster/timeseries`** | Point extraction from grids at any lat/lng | Virtual station at any location — wouldn't need to find nearest mesonet station |
| `/stations` with `period=day` | Daily-resolution historical values | Would fill the gap between monthly historical (1990+) and 5-min mesonet (2022+) |
| `/mesonet/db/measurements/email` | Large bulk exports | Not needed — we query directly |
| `/genzip/*` | Bulk zip downloads | Not needed |
| `/files/production/*` | Production file listing/retrieval | Raw data files |

The biggest gap is the **raster products** — they would let us answer spatial questions (total rainfall over an area, interpolated values between stations) without the station-sampling biases we've been working around.
