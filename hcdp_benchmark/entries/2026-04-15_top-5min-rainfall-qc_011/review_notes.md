## Review Notes

### TODO

- [ ] **Investigate station 0602 (Common Ground, Kauai) further.** This station produces repeated isolated rainfall spikes consistent with tipping bucket malfunction. Determine whether the issue is ongoing or was resolved, and whether affected readings should be flagged or removed.

- [ ] **Confirm 7999 sentinel code documentation.** Verify with the Mesonet operations team that 7999.00 is indeed a sentinel/overflow code and document the specific conditions that trigger it.

- [ ] **Propose QC filter**: A filter of `value < 100` on `RF_1_Tot300s` would catch all sentinel codes (7999) and most sensor artifacts (isolated spikes >100mm are physically impossible in 5 minutes). This is a conservative threshold — even 50mm would suffice, but 100mm provides margin.

- [ ] **Check if station 0115 sentinel codes recur.** The March 2023 event at Piiholo produced ~20 consecutive sentinel readings. Determine whether this was a one-time failure or a recurring issue.

- [ ] **Cross-reference with nearby stations.** For the 21-28mm readings (plausible range), check whether nearby stations recorded concurrent heavy rainfall to distinguish real events from artifacts.

- [ ] **Evaluate automated QC flags.** All problematic readings in this investigation carried flag=0 (no QC flag). The automated QC pipeline may need a range-check rule for 5-minute rainfall totals.
