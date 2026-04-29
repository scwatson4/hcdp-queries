# Station Reference

## Two different station ID systems

**This is the #1 source of confusion in this database.**

| System | Table | Format | Example | Used by |
|--------|-------|--------|---------|---------|
| **Mesonet ID** | `mesonet_stations`, `mesonet_measurements` | 4-digit zero-padded | `0501` | Modern mesonet (2022+) |
| **SKN** | `historical_station_values` | Numeric, often with decimal | `140.5`, `707.4` | Legacy station network (1990+) |

These are **completely different ID systems**. Station `0501` (Lyon Arboretum) in the mesonet is NOT the same as SKN `501` in the historical data. There is no join key between them in the database.

To identify which island a historical station is on, you must either:
1. Query the HCDP API: `GET /stations?q={"name":"hcdp_station_metadata"}`
2. Use the pre-cached file at `/tmp/oahu_skns.txt` (Oahu SKNs only, created during analysis)

## Mesonet stations by island

| Island | Total | Active (last 7 days) | Key stations |
|--------|-------|---------------------|--------------|
| Hawaii (Big Island) | 37 | 27 | 0213 Piihonua (Hilo area), 0254 Kawaihae (driest), 0201 Nahuku |
| Maui | 26 | 24 | 0115 Piiholo (BAD RAIN DATA), 0153 Haleakala Summit |
| Oahu | 15 | 11 | 0501 Lyon Arboretum (Manoa), 0502 Nuuanu Reservoir, 0521 Kaala |
| Kauai | 10 | 6 | 0601 Waipa, 0602 Common Ground (BAD RAIN SPIKES) |
| Molokai | 6 | 4 | 0431 Anapuka, 0421 Kualapuu |
| Unknown | 8 | 4 | 0231 Kaiholena, 0235 Manuka |

## Location-to-station mapping

When users ask about a **place name**, map it to the nearest station(s):

| Location | Station(s) | Notes |
|----------|-----------|-------|
| Manoa Valley | **0501** Lyon Arboretum (151m) | Upper valley; also 0503/0504 Waolani for mid-valley |
| UH Manoa campus | **0505** Napuumaia (508m), **0504** Waolani (98m) | Napuumaia is on the ridge above campus |
| Honolulu (general) | **0502** Nuuanu Reservoir (117m) | Best general Honolulu proxy |
| Downtown Hilo | **0281** IPIF (112m) | NOT 0213 Piihonua (606m) — that's too high |
| Hilo (general) | **0213** Piihonua (606m) | Windward upslope; wetter/cooler than downtown |
| Kona coast | **0246** Kona Research Station (446m) | Leeward Big Island |
| Kawaihae | **0254** Kawaihae (113m) | Driest station in the network |
| Haleakala summit | **0153** Haleakala Summit (2984m) | Highest station |
| North Shore Kauai | **0601** Waipa (5m) | Near Hanalei |
| Lahaina/West Maui | **0131** Lahaina WTP (244m) | Post-fire area |

**If a user asks about a location not listed here**, find the nearest station:
```sql
SELECT station_id, name, island, elevation_m,
  ST_Distance(geom, ST_SetSRID(ST_MakePoint(<lng>, <lat>), 4326)) AS dist_degrees
FROM mesonet_stations
WHERE geom IS NOT NULL
ORDER BY geom <-> ST_SetSRID(ST_MakePoint(<lng>, <lat>), 4326)
LIMIT 5;
```

## Elevation matters

When reporting weather for a low-elevation location (town, campus, beach), check the nearest station's elevation. Use the lapse rate to adjust:
- **Temperature**: roughly −6.5°C per 1,000m elevation gain
- **Humidity**: generally increases with elevation
- **Rainfall**: generally increases with elevation on windward slopes

Example: Piihonua (606m) reads 18°C → downtown Hilo (~10m) is approximately 18 + (596 × 6.5/1000) ≈ 22°C.

## Stale and broken stations

| Station | Name | Status | Issue |
|---------|------|--------|-------|
| **0115** | Piiholo, Maui | Active but rain gauge broken | Reports `7999` sentinel for RF_1_Tot300s (March 2023 event) |
| **0602** | Common Ground, Kauai | Active but rain gauge unreliable | Chronic isolated spikes (stuck tipping bucket) |
| **0122** | Kaehu, Maui | Active but soil sensor broken | Reports `7999` for SM_1_Avg |
| **0245** | Kipuka Nui, Hawaii | Stale 85+ days | Offline since Jan 2026 |
| **0532** | Palolo Mauka, Oahu | Stale 70+ days | Offline since Feb 2026 |
| ~24 stations | Various | Never reported | Planned/not-yet-deployed sites (no data in DB) |

## Historical station networks (for historical_station_values)

The legacy network includes multiple sub-networks with different characteristics:

| Network | Stations (Oahu) | Type | Status in 2022 |
|---------|----------------|------|---------------|
| COOP | 102 | Volunteer observers | **Nearly gone** (46→1 on Oahu) |
| STATE | 475 | State agencies | Not in rainfall data |
| USGS | 76 | Stream gauges | Declining (26→10 on Oahu) |
| HydroNet-UaNet | 29 | UH automated | **Stable** (core of modern network) |
| RAWS | 17 | Remote automated | **Stable** |
| CoCoRaHS | 15 | Community rain gauges | Dropped to 0 in 2022 |
| HiMesonet | 10 | Hawaii Mesonet | Growing |
| NWS | 5 | National Weather Service | Stable but small |
