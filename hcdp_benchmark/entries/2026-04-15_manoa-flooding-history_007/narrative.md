## Scientific context

Urban flash flooding in Manoa Valley is a recurring hazard driven by the valley's funnel-shaped topography, which concentrates runoff from the Koolau ridgeline into Manoa Stream. Flood risk depends on three factors: (1) rainfall intensity (mm/hr, not just daily totals), (2) antecedent soil moisture (saturated soil produces 100% runoff), and (3) upstream watershed conditions (the valley collects runoff from Kalawahine, Waolani, and the upper Koolau slopes). UH Manoa campus sits at the base of this drainage funnel.

## Methodology

Analyzed the heaviest rainfall events at 8 Manoa-area stations across five dimensions:
1. **Daily rainfall totals** at Manoa-area stations
2. **Hourly rainfall intensity** — critical for flash flood prediction; storm drains have finite capacity
3. **Multi-day rainfall accumulation** — prolonged events saturate soil before the heaviest day
4. **Antecedent soil moisture** (SM_1_Avg at Lyon Arboretum) before each event
5. **Lower-valley station readings** — Napuumaia (0505) and Waolani (0504) represent the drainage that flows toward UH campus

## Correction: March 23 vs March 13

The initial analysis ranked events by single-station daily rainfall at Lyon Arboretum, which placed March 13 (198mm) above March 23 (136mm). This was misleading. March 23 was the worse flooding event because:

### March 23, 2026 — the actual flooding event

| Factor | Value |
|--------|-------|
| **Lyon Arboretum daily** | 136mm |
| **Peak hourly intensity** | **50.8 mm/hr** (1-2 PM HST) — 2 inches/hour |
| **Antecedent soil VWC** | 63% (saturated from 148mm on Mar 20 + continued rain Mar 21-22) |
| **4-day cumulative (Mar 20-23)** | 355mm across watershed |
| **Napuumaia (above UH campus)** | **163mm** — highest of any Manoa station |
| **All 8 stations total** | 867mm combined |

The 50.8 mm/hr burst is the smoking gun. That rate exceeds typical urban storm drain capacity (~25-35 mm/hr in Honolulu). Combined with already-saturated soil and heavy upstream loading, this would produce immediate surface flooding at lower elevations — exactly where UH Manoa campus sits.

### March 13, 2026 — heavy but less flood-prone

| Factor | Value |
|--------|-------|
| **Lyon Arboretum daily** | 198mm (higher total) |
| **Peak hourly intensity** | 16.8 mm/hr — well within drainage capacity |
| **Antecedent soil VWC** | 64% (similar saturation) |
| **Napuumaia** | 72mm (less than half of March 23) |

March 13 had more total rainfall but spread over many hours. The lower intensity gave drainage systems time to handle the flow. The lower-valley stations also received less rain, meaning less runoff reaching campus.

### January 26, 2025 — significant but soil could absorb

| Factor | Value |
|--------|-------|
| **Lyon Arboretum daily** | 195mm |
| **Antecedent soil VWC** | 46% (much drier — significant absorption capacity) |
| **Multi-day context** | Single-day burst on dry ground |

## Key lesson

**Daily rainfall totals are a poor proxy for urban flood risk.** The critical factors are:
1. **Hourly intensity** — does it exceed storm drain capacity?
2. **Antecedent soil moisture** — can the ground absorb any water?
3. **Lower-elevation station readings** — where does the water end up?

A naive "sort by max daily rainfall" approach would rank March 13 first, missing the actual campus flooding on March 23.

## Limitations

- No stream gauge data to confirm actual flooding
- Storm drain capacity data would improve the analysis
- NWS flood warnings and UH emergency reports would provide ground truth
- The mesonet record only starts ~2022; earlier Manoa floods (e.g., the well-known 2004 event) are not captured
