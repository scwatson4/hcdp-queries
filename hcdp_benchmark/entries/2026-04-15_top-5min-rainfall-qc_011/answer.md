## Top 10 Highest 5-Minute Rainfall Readings

**All top 10 (and in fact, all top 20) are the 7999 sentinel error code** at station 0115 (Piiholo, Maui), recorded during March 5-6, 2023. The value 7999 is not a real rainfall measurement — it is a sensor overflow/fault code. At a rate of 95,988 mm/hr, this is physically impossible.

### After Filtering Sentinel Codes (value < 7000)

The real #1 reading is **43.64 mm in 5 minutes** at station 0602 (Common Ground, Kauai). However, this is a **single-reading spike surrounded by zeros** — a classic sensor artifact, not real weather. A genuine 43.64 mm / 5 min reading would correspond to 523.7 mm/hr, far exceeding any rainfall rate ever recorded on Earth.

### Assessment of Top Filtered Readings

**Readings 1-5 (>30 mm / 5 min): All suspicious.** These exceed the approximate world record for 5-minute rainfall intensity (~12.7 mm / 5 min). All are isolated spikes at station 0602 (Common Ground, Kauai), consistent with tipping bucket malfunction (stuck bucket releasing accumulated water, or electrical noise).

**Readings 6-10 (21-28 mm range): Plausible extreme events.** While very high, these are within the realm of possibility for intense tropical convection in Hawaii, especially during kona storms or tropical cyclone remnants. Some may still be artifacts, but they cannot be ruled out on physical grounds alone.

### Key Statistics

- Only **269 readings** in the entire database exceed 10 mm / 5 min (out of millions of records).
- **Station 0602** dominates the suspicious high readings.
- **Station 0115** is the sole source of 7999 sentinel codes.
- The database is overwhelmingly clean — data quality issues are concentrated at just 2 stations.
