## Scientific context

Hurricane Lane was a Category 5 hurricane that stalled near the Hawaiian Islands from August 22-26, 2018. Its slow movement produced extraordinary rainfall on the Big Island's windward slopes, where orographic lift enhanced already-heavy tropical cyclone precipitation. Published reports document 50-58 inches of rain at Mountain View-area stations over the 4-day event, making it one of the wettest tropical cyclones in US history.

## Data limitations

The HCDP database has two relevant datasets:
- **Mesonet measurements**: 5-minute resolution but only from 2022 — cannot see Lane
- **Historical station values**: monthly resolution back to 1990 — can see Lane's signature but cannot isolate the 4-day storm window

This means our "storm total" is actually a monthly total for August 2018, which includes non-Lane rainfall. We used two approaches to estimate Lane's contribution:
1. **Raw monthly total**: 2,166mm (85.3 in) at the wettest station
2. **Excess above normal**: compared August 2018 to average August at each station (excluding 2018), yielding ~1,700mm (~67 in) excess — a proxy for Lane's contribution

## Findings

### August 2018 was an extreme outlier
- Network-wide max: 2,166mm (vs next-highest August: 1,403mm in 2016)
- Network-wide average: 478mm (vs typical August: ~120mm)
- 23 stations exceeded 1,500mm for the month

### Top stations (Big Island windward)
| Station SKN | Aug 2018 total | Normal August | Lane excess |
|-------------|---------------|---------------|-------------|
| 140.5 | 2,166mm (85.3 in) | 475mm | ~1,691mm (66.6 in) |
| 277 | 2,142mm (84.3 in) | 442mm | ~1,700mm (66.9 in) |
| 88.2 | 2,060mm (81.1 in) | 416mm | ~1,644mm (64.7 in) |
| 88.1 | 2,055mm (80.9 in) | 427mm | ~1,628mm (64.1 in) |
| 55.4 | 2,025mm (79.7 in) | 477mm | ~1,548mm (60.9 in) |

### Comparison to published storm totals

Published daily-resolution totals report 50-58 inches (1,270-1,473mm) for Aug 22-26. Our monthly excess (~1,700mm / 67 in) is ~15-30% higher because:
1. The monthly total includes non-Lane rain from the rest of August
2. The "normal August" baseline is an average — actual non-Lane rain in Aug 2018 may have been higher or lower
3. Some Lane-adjacent rain bands may have extended beyond the Aug 22-26 window

The monthly proxy is directionally correct and within the right order of magnitude, but overstates the actual storm total.

## Implications for the benchmark

This entry tests whether an agent can:
1. Recognize that the mesonet data starts too late and pivot to historical data
2. Understand the resolution limitation of monthly aggregates
3. Use a baseline-subtraction approach to estimate event-specific rainfall
4. Appropriately caveat the result given the temporal resolution mismatch
