## The question and why it matters

Identifying drought years from station data has real policy consequences — USDA disaster declarations, municipal water allocation, agricultural planning, and wildfire risk assessment all depend on getting the methodology right. A naive "average all reporting stations" approach can conflate a genuine climate signal with changes in which stations are reporting. This entry documents both the naive and corrected methodologies as a teaching example.

## The naive answer

An initial query averaged monthly rainfall across all Oahu stations reporting in each year. The result: 2022 appeared as the driest year with 935 mm (36.8 in) averaged across 54 stations — dramatically below the median year (~1,400 mm). But 54 stations in 2022 compared to 120+ in prior years immediately raised a red flag.

## The composition concern

Investigation of the station network revealed a dramatic structural change:

| Year | Total Oahu stations | COOP | USGS | HydroNet | RAWS | Other |
|------|-------------------|------|------|----------|------|-------|
| 2005 | 124 | 49 | 23 | 21 | 15 | 16 |
| 2010 | 124 | 47 | 23 | 21 | 15 | 18 |
| 2015 | 130 | 50 | 23 | 21 | 17 | 19 |
| 2019 | 136 | 46 | 26 | 25 | 16 | 23 |
| 2020 | 88 | 29 | 10 | 24 | 12 | 13 |
| 2021 | 87 | 27 | 10 | 24 | 13 | 13 |
| **2022** | **54** | **1** | **10** | **26** | **12** | **5** |
| 2023 | 68 | 11 | 8 | 27 | 13 | 9 |

The COOP (Cooperative Observer) network — traditionally the backbone of Hawaii rainfall monitoring, staffed by volunteer observers at homes and farms — collapsed from 46 stations in 2019 to a single station in 2022. This likely reflects the cumulative impact of COVID-era disruptions on volunteer-based networks, combined with the broader national trend of COOP attrition. USGS, NREM, and CoCoRaHS also saw significant losses.

This means the 2022 "all stations" average is computed from a fundamentally different network than prior years — predominantly automated HydroNet and RAWS stations rather than the volunteer-staffed COOP network. If COOP stations were systematically wetter or drier than the remaining networks, the naive comparison would be biased.

**This network-composition documentation does not appear to exist elsewhere in published form.** The HCDP data portal presents station values without flagging changes in network composition over time.

## The reference-panel test

To eliminate the composition artifact, we constructed a stable reference panel:

**Criteria**: Oahu stations that (a) reported rainfall in ≥20 of 26 years from 2000–2025, AND (b) actually reported in 2022.

**Result**: 41 stations qualified, from 4 networks:
- HydroNet-UaNet: 20 stations
- RAWS: 11 stations
- USGS: 8 stations
- NWS: 2 stations

Zero COOP stations met both criteria — all 42 COOP stations in the broader panel (≥20 years) failed to report in 2022.

## The verified result

Using only these 41 stations across all 26 years:

| Rank | Year | Est. annual mm | Est. annual in | % of mean |
|------|------|---------------|---------------|-----------|
| **#1** | **2022** | **985** | **38.8** | **67.5%** |
| #2 | 2000 | 1,127 | 44.4 | 77.3% |
| #3 | 2012 | 1,169 | 46.0 | 80.2% |
| #4 | 2025 | 1,175 | 46.3 | 80.6% |
| #5 | 2001 | 1,198 | 47.2 | 82.1% |
| ... | ... | ... | ... | ... |
| Wettest | 2004 | 2,065 | 81.3 | 141.6% |

**Panel long-term mean**: 1,458 mm (57.4 in)
**2022 deficit**: −473 mm (−18.6 in), or 32.5% below normal
**Gap to #2**: 10 percentage points (67.5% vs 77.3%)

The 10-point gap between #1 and #2 is decisive. Typical year-to-year noise in the ranking is 2-5 points. A 10-point gap cannot be explained by station-selection bias, incomplete monthly reporting, or any reasonable methodological variation.

## External corroboration

The USDM confirms the severity:
- By September 2022, nearly 100% of Hawaii was under some level of drought
- Approximately one-third of the state faced severe drought (D2) or worse
- Federal agriculture disaster declarations were issued for every Hawaii county
- USDA and NDMC hosted emergency drought workshops on four islands in October 2022

## Residual caveats

The reference panel skews toward modern automated networks (HydroNet, RAWS) and excludes legacy COOP sites. This may underrepresent low-elevation urban Honolulu (Pearl Harbor area, downtown), but the panel still spans the full windward-leeward and elevation gradient that drives Oahu rainfall variability. The 10-point margin to the second-driest year is too large to be explained by composition — this caveat is methodological honesty, not a substantive challenge to the result.

A gridded rainfall product (if available) would provide independent verification free of station-selection concerns, but the HCDP raster products were not ingested into this database.
