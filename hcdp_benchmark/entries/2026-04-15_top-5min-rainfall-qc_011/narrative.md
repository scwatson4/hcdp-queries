## Data Quality in Automated Rain Gauge Networks

Automated tipping bucket rain gauges are the backbone of real-time precipitation monitoring, but they are susceptible to several classes of measurement error that can produce extreme outlier readings. Understanding these failure modes is essential for anyone working with high-frequency rainfall data.

### Tipping Bucket Malfunctions

A tipping bucket gauge works by funneling rain into a small bucket that tips when it reaches a calibrated volume (typically 0.254 mm or 0.01 inches). Each tip generates an electrical pulse that the datalogger counts. This elegant mechanism can fail in several ways:

- **Stuck bucket dumps**: If the bucket mechanism sticks (due to debris, spider webs, or mechanical wear), water accumulates until the obstruction clears. The bucket then tips rapidly in succession, producing a single enormous reading followed by zeros — exactly the pattern seen at station 0602.

- **Electrical noise**: Lightning, corroded wiring, or failing electronics can generate false tip signals, producing spurious rainfall readings with no actual precipitation.

- **Clogged funnel**: Leaves, bird droppings, or insects can partially block the collection funnel, causing erratic catch behavior.

### Physical Plausibility Thresholds

The world record for 5-minute rainfall is approximately 12.7 mm (0.5 inches), recorded under extreme tropical convection. For the Hawaii Mesonet, readings exceeding this threshold deserve scrutiny:

- **>50 mm / 5 min**: Physically impossible. Sensor fault or sentinel code.
- **30-50 mm / 5 min**: Almost certainly a sensor artifact. Exceeds 2-3x the world record.
- **15-30 mm / 5 min**: Suspicious but not impossible in extreme tropical events. Requires context checking.
- **10-15 mm / 5 min**: Rare but plausible for intense Hawaiian rainfall (kona storms, tropical cyclone bands).

### The 7999 Sentinel Code Pattern

Station 0115 (Piiholo, Maui) produced a sustained block of 7999.00 mm readings during March 5-6, 2023. This value is a sentinel code — a special value written by the datalogger firmware to indicate sensor overflow, communication failure, or diagnostic mode. It is not a measurement. The value 7999 was likely chosen to be obviously impossible (nearly 8 meters of rain in 5 minutes) so that it would be easy to identify and filter.

The fact that these sentinel codes carry flag=0 (no QC flag set) indicates that the automated QC system did not catch them. This is a gap in the QC pipeline — a simple range check (value < 100 mm for a 5-minute total) would eliminate all sentinel codes.

### Station 0602: A Systematic Problem

Station 0602 (Common Ground, Kauai) appears repeatedly in the top rainfall readings after sentinel codes are filtered out. The readings share a consistent pattern:

1. A single 5-minute reading with an extreme value (30-44 mm)
2. Zero or near-zero readings in the intervals immediately before and after
3. No corroboration from nearby stations

This pattern is the hallmark of a tipping bucket malfunction — specifically, a stuck bucket that periodically releases. Real extreme rainfall events produce elevated readings across multiple consecutive intervals and are typically observed at nearby stations as well.

### The Big Picture

Despite these issues, the Hawaii Mesonet database is overwhelmingly clean. Only 269 readings out of millions exceed 10 mm / 5 min, and the problematic readings are concentrated at just two stations (0115 for sentinel codes, 0602 for mechanical artifacts). This means the data quality issues affect far less than 0.01% of the dataset.

The lesson is not that the data is unreliable, but that automated QC pipelines need explicit handling for:
1. Sentinel/overflow codes (range filters)
2. Isolated spikes (temporal context checks)
3. Physical plausibility limits (rate-based filters)

A simple filter of `value < 100` on the RF_1_Tot300s variable would catch every problematic reading identified in this investigation.
