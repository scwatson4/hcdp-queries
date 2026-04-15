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

Station 0602 (Common Ground, Kauai, 112m, near Hanalei) appears 5 times in the top 12 readings. Detailed context analysis of each spike:

**Spike 1: 2024-03-02, 43.64mm — FAKE.** `0→0→0→0→0→0→43.64→0→0→0→0→0→0`. A single reading surrounded by 30+ minutes of zeros on both sides. Classic stuck-bucket dump.

**Spike 2: 2023-02-05, 32.88+42.94mm burst — FAKE (during real rain).** `0.5→0.5→0.8→0.8→1.0→1.3→32.88→42.94→11.87→0.25→0→0`. There was real rain building (gradual ramp from 0.5 to 1.3mm/5min), then the gauge dumped 87.7mm over two readings. The funnel or bucket got obstructed during real precipitation, water pooled, then released all at once.

**Spike 3: 2024-11-05, 31.96mm — LIKELY FAKE.** `0.25→0→0→0→0→9.66→31.96→0→0→0→0→0→0`. Small precursor (9.66mm), then a 32mm spike, then nothing. Another dump pattern.

**Spike 4: 2025-03-12, 20.19mm — AMBIGUOUS.** `0.25→0→1.0→1.8→2.0→6.7→20.19→0→0→0`. Clear ramp-up that looks more like a genuine intense convective cell peaking and ending. 20mm/5min (240 mm/hr) is extreme but not impossible. However, the instant drop to zero is unusual — real storms typically taper off.

The consistent pattern across years suggests a chronic hardware issue — likely a partially clogged funnel or sticky bucket mechanism that periodically accumulates and dumps.

### The Big Picture

Despite these issues, the Hawaii Mesonet database is overwhelmingly clean. Only 269 readings out of millions exceed 10 mm / 5 min, and the problematic readings are concentrated at just two stations (0115 for sentinel codes, 0602 for mechanical artifacts). This means the data quality issues affect far less than 0.01% of the dataset.

The lesson is not that the data is unreliable, but that automated QC pipelines need explicit handling for:
1. Sentinel/overflow codes (range filters)
2. Isolated spikes (temporal context checks)
3. Physical plausibility limits (rate-based filters)

A simple filter of `value < 100` on the RF_1_Tot300s variable would catch every problematic reading identified in this investigation.
