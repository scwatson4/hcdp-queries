## Scientific context

Understanding the inventory and temporal coverage of a climate database is foundational for any analysis. Gaps in station coverage, changes in network size, and differences in temporal resolution between products all affect what questions can be answered and how results should be interpreted.

## Data products in the database

### Mesonet 5-minute measurements (2022-present)
The Hawaii Mesonet is a relatively new network that began reporting in January 2022 with 19 stations and rapidly expanded to 78 by 2025. Each station reports ~279 variables every 5 minutes, producing ~390M rows/year at current station count. This is the bulk of the database (961M rows, 66 GB table + 121 GB indexes).

Year-by-year growth:
- 2022: 19 stations, 36M rows
- 2023: 44 stations, 135M rows (largest single-year expansion)
- 2024: 63 stations, 280M rows
- 2025: 78 stations, 390M rows
- 2026: 78 stations, 120M rows (through April 15)

### Historical monthly station values (1990-2026)
A separate, older station network with monthly-resolution rainfall and temperature. Coverage peaked at 564 stations in the 1990s-2000s and has declined to ~270 by 2022. This network uses different station identifiers (SKN numbers) from the mesonet.

Notable coverage decline:
- 2010: 512 stations
- 2015: 487 stations
- 2020: 328 stations (36% drop from 2010)
- 2022-2026: ~270 stations (stabilized)

This attrition likely reflects maintenance budget constraints and the transition to automated mesonet stations.

### Materialized views (derived from mesonet)
Two materialized views aggregate mesonet 5-minute data:
- **Daily summary**: rainfall, temperature min/max/mean per station per day
- **Monthly summary**: same aggregated to monthly level

These mirror the mesonet station count exactly and exist only for the mesonet period (2022+).

## What's NOT in the database

The HCDP API offers several additional data products not ingested:
1. **Gridded raster maps** (GeoTIFF): rainfall, temperature, SPI drought index — spatial grids, not point stations
2. **Daily-resolution historical station values**: available via the `/stations` API with `period=day` but only monthly was ingested
3. **Raster time series**: point extractions from the gridded maps at arbitrary lat/lng

## Coverage gap analysis

There is a fundamental gap between the two main datasets:
- **Historical monthly**: broad spatial coverage (500+ stations) but coarse temporal resolution (monthly)
- **Mesonet 5-min**: fine temporal resolution (5-min) but fewer stations (78) and shorter record (2022+)

The overlap period (2022+) has both, but they use different station networks and identifiers. For events before 2022, only monthly data is available. For sub-daily analysis, only 2022+ mesonet data can be used.
