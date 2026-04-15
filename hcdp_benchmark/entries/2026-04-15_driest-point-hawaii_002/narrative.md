## Scientific context

The Hawaiian Islands exhibit extreme rainfall gradients driven by orographic effects — trade winds force moist air upward on windward slopes, producing heavy precipitation, while leeward areas sit in a rain shadow. Annual rainfall can vary from ~250 mm on leeward coasts to >11,000 mm on windward summits within a few kilometers.

## Methodology

Queried the `mv_daily_station_summary` materialized view joined with `mesonet_stations` for station metadata. Filtered to stations with >365 days of data to ensure a meaningful average. Ranked by average daily rainfall ascending.

## Key findings

The top 10 driest stations are all on leeward coasts or in rain shadow zones:
1. **Kawaihae** (Big Island, 113m, leeward Kohala coast): 0.97 mm/day, ~353 mm/yr
2. **Lipoa** (Maui, 88m): 1.35 mm/day, ~494 mm/yr
3. **Kula Ag Station** (Maui, 964m, upper slope): 1.41 mm/day, ~514 mm/yr

All dry-side stations cluster in leeward West Hawaii, South/West Maui, and leeward Molokai. The wettest mesonet stations receive 15-20x more rainfall.

## Limitations

- Only covers mesonet stations (103 total, 74 with rainfall); some very dry areas may not have stations
- Mesonet data starts ~2022; longer records might shift rankings
- Daily aggregation may miss sub-daily rain events differently across stations
