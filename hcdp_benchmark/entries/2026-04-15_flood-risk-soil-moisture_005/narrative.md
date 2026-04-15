## Scientific context

Flood risk depends not just on rainfall intensity but on antecedent soil moisture. Saturated soil has zero infiltration capacity — all rainfall becomes surface runoff. Volumetric water content (VWC) measured by the mesonet's soil moisture probes (SM_1_Avg, in m³/m³) indicates how close the soil is to saturation. Values above ~0.50 indicate high saturation; above ~0.60 the soil is effectively saturated for most Hawaiian soil types.

## Methodology

Combined three data sources in a single CTE query:
1. **Current soil moisture**: latest SM_1_Avg reading per station (excluding sensor errors where value >= 1)
2. **7-day trend**: compared current VWC to reading from 7 days prior to assess trajectory
3. **Recent rainfall**: sum of RF_1_Tot300s over past 48 hours (excluding 7999 error codes)

Classified flood risk using simple thresholds:
- HIGH: VWC > 55% AND 48h rain > 50mm (saturated + actively raining)
- MODERATE: VWC > 50%, or VWC > 40% with 48h rain > 100mm
- LOW: VWC > 40%
- MINIMAL: VWC <= 40%

## Key findings

### Most saturated (highest runoff potential)
- Kaala, Oahu (1205m): 74.1% VWC — essentially saturated
- Kehena Ditch Cabin, Hawaii (1158m): 73.5% VWC, rising
- Kaluanui Ridge, Oahu (239m): 70.6% VWC, rising +2.3%/week

### Fastest rising (wetting rapidly)
- Lahaina WTP, Maui: +19.8% in one week (from ~29% to 49%)
- Lipoa, Maui: +16.6% in one week
- Kaiāulu Puuwaawaa, Hawaii: +11.7% in one week

### Regional patterns
- **Windward Oahu**: highest absolute saturation — Kaala, Kaluanui, Kaaawa Makai, Nuuanu corridor all >57% VWC
- **West Maui**: fastest wetting — previously dry soils rapidly absorbing from recent rains
- **Molokai**: Anapuka rising +10.8%, Honoulimaloo +5.1%

## Data quality note

Station 0122 (Kaehu, Maui) reports SM_1_Avg = 7999 — the same sensor error sentinel found in the RF_1_Tot300s investigation (entry 004). This was filtered from the analysis by the `value < 1` clause.

## Limitations

- Soil moisture thresholds for flooding vary by soil type (clay vs volcanic ash vs alluvium)
- Only surface soil moisture is measured; deeper soil layers affect drainage differently
- Topographic slope and proximity to streams are not captured by this point-station analysis
- The flood risk classification is a simple heuristic, not a calibrated hydrological model
