## Scientific context

This query requires bridging point-station rainfall measurements to a volumetric estimate across an entire archipelago. Hawaii's rainfall distribution is among the most spatially heterogeneous on Earth — Mt. Waialeale on Kauai receives ~11,000 mm/yr while Kawaihae on the Big Island receives ~250 mm/yr, separated by only ~150 km.

## Methodology

Two data sources were combined:
1. **Mesonet daily summaries** (74 stations): provided per-island breakdowns showing Maui (785 mm), Oahu (756 mm), and Molokai (708 mm) as the wettest islands, with Kauai anomalously low (250 mm) — likely because its 6 stations skew toward drier coastal locations.
2. **Historical station network** (133 stations): provided a statewide average of 529.03 mm for March 2026, with better spatial coverage.

The historical network average was multiplied by total Hawaiian island land area (16,627 km²) to produce the volumetric estimate.

## Key assumptions and limitations

- Land area only (16,627 km²) — excludes rainfall over surrounding ocean
- Station averages may over-represent wetter or higher-elevation locations where stations tend to be placed
- Neither network is a uniform spatial grid — a proper estimate would use the HCDP gridded rainfall raster product
- The conversion assumes uniform rainfall across each island, which is physically unrealistic given orographic effects

## Result

~2.3 trillion gallons (8.8 km³) of rain fell on the Hawaiian Islands in March 2026.
