# Review Notes -- Station Freshness Check (008)

## Verification Checklist

- [ ] Run query.sql against the live database and compare output to results.csv
- [ ] Confirm total station count matches mesonet_stations table (expect 103)
- [ ] Verify STALE stations: confirm Kipuka Nui (0245) and Palolo Mauka (0532) last readings
- [ ] Verify NEVER stations: confirm zero rows in mesonet_measurements for each
- [ ] Check that LEFT JOIN correctly includes stations with no measurements
- [ ] Validate that the 7-day threshold is appropriate for the reporting interval
- [ ] Confirm elevation values match authoritative station metadata
- [ ] Spot-check 5 OK stations against raw measurement timestamps
- [ ] Verify ORDER BY produces STALE first, then NEVER, then OK (descending alpha)
- [ ] Review island assignments for stations currently listed as "Unknown"

## Open Questions

- [ ] Should the staleness threshold be shorter than 7 days (e.g., 24 hours)?
- [ ] Are the "Unknown" island stations misclassified, or is the metadata genuinely missing?
- [ ] What is the expected deployment timeline for NEVER stations?

## Sign-off

- Reviewer: _______________
- Date: _______________
- Status: PENDING
