Four data products in the database, no gridded/raster data:

**Mesonet 5-min** (`mesonet_measurements`): 961M rows, 2022-01-01 to present. Network grew from 19 stations (2022) to 78 (2025-26). ~390M rows/year at current station count.

**Historical monthly** (`historical_station_values`): 228k rows, 1990-01 to 2026-03. Station count peaked at 564 (1990s-2000s), dropped to ~270 by 2022 — roughly 50% attrition. Covers rainfall and temperature.

**Daily summary** (`mv_daily_station_summary`): Materialized view derived from mesonet. 69k rows, 2022-2026. Mirrors mesonet station growth.

**Monthly summary** (`mv_monthly_station_summary`): Materialized view derived from mesonet. 2.4k rows, 2022-2026.

**Not ingested**: HCDP gridded rainfall/temperature rasters (GeoTIFF), daily-resolution historical station values, SPI drought index rasters. These are available via the API but weren't loaded into PostgreSQL.

Notable trend: the historical network shrank from 512 stations (2010) to 270 (2022+) while the mesonet grew from 19 to 78 — different networks, partial overlap.
