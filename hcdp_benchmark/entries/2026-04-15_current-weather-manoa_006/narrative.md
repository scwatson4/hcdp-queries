## Scientific context

Manoa Valley on Oahu is one of the wetter urban areas in Hawaii, receiving ~3,800 mm (150 in) of rainfall annually at its upper end. Lyon Arboretum (station 0501) sits at 151m elevation in the upper valley, making it representative of conditions in the wetter, windward-facing portion of the Manoa watershed.

## Methodology

This query requires two steps:
1. **Station selection**: identify which mesonet station is closest to or most representative of "Manoa" — Lyon Arboretum (0501) is the obvious choice as it is physically located in upper Manoa Valley
2. **Current conditions**: retrieve the latest timestamp's readings for key weather variables (temperature, humidity, wind, rainfall, soil moisture)

A supporting query summed the last 24 hours of 5-minute rainfall totals to provide precipitation context.

## Key findings

Conditions at 2:45 PM HST on April 15, 2026:
- **Temperature**: 25.6°C (78°F) — typical mid-afternoon for April
- **Humidity**: 85% — characteristically high for Manoa
- **Wind**: 0.16 m/s — essentially calm, consistent with sheltered valley location
- **Rainfall**: No rain in last 24h
- **Soil moisture**: 59.4% VWC — elevated, indicating recent prior rain events have saturated the soil

## Limitations

- This is a point-in-time snapshot; results change with every 5-minute update
- Lyon Arboretum represents upper Manoa Valley; conditions at lower elevations (UH campus, residential areas) may differ
- No barometric pressure or solar radiation available in this reading (those sensors may be offline or not present at this station)
