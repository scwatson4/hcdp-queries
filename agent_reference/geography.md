# Hawaiian Geography for Climate Analysis

## Island areas

| Island | Area (km²) | Notes |
|--------|-----------|-------|
| Hawaii (Big Island) | 10,432 | Largest; two 4,000m volcanoes; extreme rainfall gradients |
| Maui | 1,883 | Haleakala (3,055m); West Maui Mountains |
| Oahu | 1,545 | Most populated; Koolau and Waianae ranges |
| Kauai | 1,435 | Wettest island overall; Mt. Waialeale |
| Molokai | 673 | High sea cliffs; limited station coverage |
| Lanai | 364 | No mesonet stations |
| Niihau | 180 | No mesonet stations |
| Kahoolawe | 115 | Uninhabited, no stations |
| **Total** | **16,627** | |

## Orographic rainfall — the dominant climate pattern

Hawaii's rainfall is driven almost entirely by **orographic effects** — northeast trade winds push moist oceanic air against volcanic mountain slopes:

1. **Windward (northeast) slopes**: Trade winds force moist air upward → cooling → condensation → heavy rainfall. Stations here get 3,000-5,000+ mm/yr.

2. **Leeward (southwest) slopes**: Descending dry air on the downslope side → rain shadow. Stations here get 250-600 mm/yr.

3. **Summit zones**: Above the trade wind inversion (~1,800-2,400m), air is dry. Summit stations (Haleakala, Mauna Kea) are drier than mid-elevation windward stations.

4. **Kona storms**: Winter low-pressure systems approach from the south/southwest, reversing the typical pattern. Normally dry leeward Kona coast gets heavy rain. These drive the most extreme multi-island rain events.

**The wet/dry ratio can exceed 10x within a single island.** Piihonua (windward Big Island, 4,414 mm/yr) vs Kawaihae (leeward Big Island, 353 mm/yr) — same island, 75 km apart, 12.5x difference.

## Key geographic zones by island

### Hawaii (Big Island)
- **Windward (Hilo/Hamakua coast)**: Wettest area. Stations: 0213 Piihonua, 0283 Laupahoehoe, 0212 Kulaimano
- **Leeward (Kona/Kohala coast)**: Driest area. Stations: 0254 Kawaihae (driest in network), 0286 Palamanui
- **Saddle/upland**: High elevation between Mauna Kea and Mauna Loa. Stations: 0211 Kanakaleonui (2,352m)

### Maui
- **Windward (east)**: Wet. Stations: 0154 Waikamoi, 0155 East Maui Irrigation
- **Leeward (west)**: Dry. Stations: 0121 Lipoa, 0132 Olowalu, 0131 Lahaina WTP
- **Haleakala**: High-altitude stations from 713m to 2,984m (summit)
- **South Maui (Kahikinui)**: Very dry leeward slope

### Oahu
- **Windward (Koolau range)**: Wet. Stations: 0501 Lyon Arboretum (Manoa), 0521 Kaala (wettest on Oahu)
- **Leeward (Waianae coast)**: Drier. Limited station coverage.
- **Urban Honolulu**: 0502 Nuuanu Reservoir, 0504 Waolani — transition zone

### Kauai
- **North shore (Hanalei area)**: Very wet. Stations: 0601 Waipa, 0602 Common Ground
- **Mt. Waialeale**: One of the wettest spots on Earth (~11,000 mm/yr) — no mesonet station directly on the summit

## Seasonal patterns

Hawaii has two seasons:
- **Wet season (Kona season)**: November–March. Kona lows, cold fronts, and upper-level troughs bring widespread rain.
- **Dry season (trade wind season)**: April–October. Persistent northeast trade winds; rain mostly confined to windward slopes.

The wet/dry distinction is strongest on leeward coasts. Windward areas get rain year-round.

## Extreme events

| Event type | Frequency | Impact | Identifiable in this DB? |
|-----------|-----------|--------|-------------------------|
| **Kona low** | 5-10/year in wet season | Multi-island heavy rain, 200-700mm/day | Yes (mesonet 2022+, monthly proxy pre-2022) |
| **Hurricane/tropical cyclone** | Rare (1-2/decade near Hawaii) | Extreme rain, wind | Monthly proxy only (Hurricane Lane 2018) |
| **Flash flooding** | Several/year | Urban damage, stream overflow | Yes — check hourly intensity + soil moisture |
| **Drought** | Multi-year episodes | Agriculture, wildfire, water supply | Yes — annual trend analysis (use reference panel!) |
| **Trade wind inversion** | Daily | Caps cloud height, limits upslope rain | Not directly measurable from station data |

## Volumetric rainfall estimates

To estimate total rainfall volume over an area:
1. Get average rainfall depth (mm) from station network
2. Multiply by area (km² → m², × 10⁶)
3. Convert depth to meters (÷ 1,000)
4. Result is in m³

Conversion: 1 m³ = 264.172 US gallons

**Caveat**: Station averages are point measurements, not spatial averages. The HCDP gridded raster products would give better spatial estimates but are not in this database.
