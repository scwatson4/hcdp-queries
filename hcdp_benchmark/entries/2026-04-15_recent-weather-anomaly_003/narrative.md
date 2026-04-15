## Scientific context

Hawaii experiences several types of extreme rainfall events: Kona lows (upper-level low-pressure systems), tropical cyclones, and orographic enhancement of trade wind showers. Kona lows are particularly dangerous because they affect multiple islands simultaneously and can stall, producing prolonged heavy rain.

## Methodology

Queried the top 20 single-station-day rainfall totals from the past 6 months using `mv_daily_station_summary`. Then examined the temporal pattern around the peak dates to characterize the event's duration and spatial extent.

## Key findings

The March 13-14, 2026 event dominates the extreme rainfall record:
- **Peak**: 711 mm (28 in) at Nahuku, Big Island — the highest single-day reading in the entire database
- **Breadth**: 46/74 stations (62%) exceeded 100 mm; 15 exceeded 250 mm
- **Multi-island**: Big Island, Maui, and Oahu all heavily impacted
- **Duration**: Two-day event; March 13 network total 8,526 mm, March 14 total 12,917 mm
- **Context**: Normal March day averages 3-6 mm across the network; March 14 averaged 174.6 mm/station (30x normal)
- **Recovery**: Rainfall dropped to near-normal by March 16

Also notable: the investigation revealed station 0115 (Piiholo, Maui) has sensor error data from March 2023 that was contaminating historical statistics (see entry 004).

## Limitations

- "Anomaly" is subjective; this analysis simply ranked by absolute magnitude rather than statistical deviation from a baseline
- A proper anomaly detection would use z-scores against monthly climatology per station
- Without sub-daily data analysis, we cannot characterize rainfall intensity (mm/hr) which is critical for flash flood risk
