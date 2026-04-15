# Mesonet Network Health: Station Freshness Check

## Overview

The Hawaii Mesonet is a distributed network of 103 weather stations spanning the major Hawaiian islands. These stations report environmental measurements (temperature, humidity, rainfall, wind, solar radiation, soil moisture, etc.) at approximately 5-minute intervals. Continuous, reliable data flow from every station is critical to climate research, agricultural planning, wildfire risk assessment, and weather forecasting across the archipelago.

## Why Freshness Monitoring Matters

Data quality depends on timely delivery. A station that silently stops reporting creates gaps in spatial coverage that can bias interpolated climate maps, miss localized weather events, and degrade model inputs. Automated freshness checks -- comparing each station's most recent timestamp against a staleness threshold -- are the first line of defense. A 7-day threshold is conservative for stations that nominally report every 5 minutes; even a few hours of silence warrants investigation, but 7 days provides an unambiguous signal of a problem.

## Current Network Status (as of 2026-04-15)

- **67 stations** are actively reporting, with their most recent readings within the last 45 minutes.
- **2 stations** are flagged STALE, meaning they have historical data but have not reported in over 7 days:
  - **Kipuka Nui (station 0245)** -- located at 1,176 m elevation on the Big Island. Last reported on 2026-01-20, making it silent for approximately 85 days.
  - **Palolo Mauka (station 0532)** -- located at 714 m elevation on Oahu. Last reported on 2026-02-04, making it silent for approximately 70 days.
- **~24 stations** are flagged NEVER, meaning they exist in the station registry but have zero measurement records. These are believed to be planned installations or stations that have been registered but not yet physically deployed and connected.

## Stale Station Analysis

Both stale stations are at moderate-to-high elevations, which increases exposure to harsh weather conditions (high winds, heavy rain, lightning) that can damage equipment. Possible causes include:

- **Hardware failure**: sensor malfunction, datalogger failure, or antenna damage.
- **Power loss**: solar panel degradation, battery failure, or vegetation overgrowth shading the solar array.
- **Communication failure**: cellular modem issues, SIM card expiration, or network coverage changes.
- **Physical damage**: vandalism, animal interference, or storm damage to the station structure.

Kipuka Nui at 1,176 m on the Big Island sits in a remote forested area where field access may be difficult, potentially explaining the extended outage duration. Palolo Mauka at 714 m on Oahu is more accessible but still in a relatively remote ridgeline location.

## Planned / Not-Yet-Online Stations

The ~24 NEVER stations are distributed across all islands, with concentrations on Hawaii Island and Kauai. Several lack elevation metadata, which is consistent with stations that have been registered in the database ahead of physical deployment. These represent planned network expansion and should be monitored separately -- their transition from NEVER to OK will indicate successful deployment.

## Recommendations

1. **Prioritize field visits** to Kipuka Nui and Palolo Mauka to diagnose and repair the outages.
2. **Implement automated alerting** that triggers after 24 hours of silence from any station, rather than relying on periodic manual checks.
3. **Track NEVER stations** in a deployment pipeline with expected online dates so that delays are visible.
4. **Audit communication infrastructure** (cellular contracts, modem firmware) on a regular schedule to prevent silent failures.
