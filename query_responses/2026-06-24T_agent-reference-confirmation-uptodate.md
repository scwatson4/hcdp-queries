# Confirmation: do the up-to-date agent docs reflect how I answer HCDP queries?

**Date:** 2026-06-24
**Scope:** second, in-depth review of the agent-facing files under `jetstream2/` — this time the
**current/deployed** versions (after redeploying `qgis-glue@7748790` to the instance), checking
whether they encode the methodology that produced correct "driest station" answers this session.
Read-only except the doc redeploy already completed. No secrets in this document.

> Context: the *first* gap-analysis report graded a stale deployed copy and was corrected. This
> report reviews the **current** docs, now deployed.

---

## Verdict

**Yes — the up-to-date docs faithfully reflect how I'd answer, and in one place improve on it.**
Confirmed two ways: (1) tracing each technique I used this session to its home in the docs, and
(2) running the docs' prescribed query against the live DB to verify it produces the right answer.

---

## Every technique that produced correct answers is now encoded

| What I did this session | Where it now lives (deployed) |
|---|---|
| Rank the *same single month* you map, not a multi-year average | `CLAUDE.md` trap 1 + `query_patterns.md` "Station ranking for ONE month" |
| Completeness guard (don't trust partial-month totals) | `query_patterns.md` + `data_quality.md` Rule 6 |
| Stuck-zero sanity check (Waipā fail / Kawaihae-recovers / Haleakalā flag) | `data_quality.md` Rule 7 — my exact examples, ~verbatim |
| `% of normal` via the 1991–2010 climatology | `data_products.md` "Numeric normals" (`/climatology/sample`) |
| Network selection (mesonet vs portal's historical grid) | `CLAUDE.md` trap 4 |
| Two-directional contamination (dry side is the harder one) | `methodology.md` Pitfall 6 |
| Units (mm, ÷ 25.4) | `CLAUDE.md` rule 4 + query patterns |

## Empirical check — the docs' prescribed recipe reproduces the right answer

I ran the docs' recommended **rate-based** "ONE month" recipe verbatim for May 2026:

```sql
SELECT s.name, s.island,
  COUNT(*) AS days_reporting,
  ROUND(AVG(d.rainfall_mm)::numeric, 2) AS avg_daily_mm,
  ROUND(SUM(d.rainfall_mm)::numeric, 1) AS month_mm
FROM mv_daily_station_summary_qc d
JOIN mesonet_stations s ON s.station_id = d.station_id
WHERE d.date_hst >= '2026-05-01' AND d.date_hst < '2026-06-01'
  AND d.rainfall_mm IS NOT NULL
GROUP BY s.station_id, s.name, s.island
ORDER BY AVG(d.rainfall_mm) ASC LIMIT 12;
```

Result (matches my earlier total-based top-10 — same leeward stations, same stuck-zero leaders):

| name | island | days_reporting | avg_daily_mm | month_mm |
|---|---|---|---|---|
| Haleakalā Summit | Maui | 31 | 0.00 | 0.0 |
| Kawaihae | Hawaii | 31 | 0.00 | 0.0 |
| Līpoa | Maui | 31 | 0.02 | 0.5 |
| Waipā | Kauai | 31 | 0.02 | 0.8 |
| Auwahi | Maui | 26 | 0.07 | 1.8 |
| Nāʻiwa | Molokai | 31 | 0.09 | 2.8 |
| Anapuka | Molokai | 31 | 0.17 | 5.4 |
| Pūlehu | Maui | 31 | 0.34 | 10.5 |
| Kahikinui | Maui | 31 | 0.35 | 10.8 |
| Olowalu | Maui | 31 | 0.36 | 11.2 |
| Lahaina Water Treatment Plant | Maui | 31 | 0.38 | 11.7 |
| Upper Kahikinui | Maui | 31 | 0.44 | 13.7 |

It also surfaced **Auwahi (26 days, 0.07 mm/day)** *with its day count*, instead of silently
excluding it the way my ≥28-day total guard would have. Waipā still appears (rate doesn't catch a
stuck-zero) — which is exactly why the docs also prescribe the Rule 7 climatology cross-check.

## Where the docs go BEYOND my session approach (and I endorse it)

The docs rank by **average daily rate, including every station and showing the day count**, rather
than my "monthly total with a ≥28-day exclusion." The rate method is better: it's coverage-
comparable by construction and surfaces thin-sample stations with an uncertainty signal instead of
discarding real dry signal. I'd adopt the docs' approach over my own here.

## Three small residual gaps (route through the repo — do NOT edit the deployed copy)

1. **`methodology.md` "Checklist before answering" lags its own prose.** Pitfall 6's body is now
   two-directional, but the 7-item checklist still has only the high-side item ("checking
   surrounding readings for isolated spikes"). An agent running just the checklist would still miss
   completeness / stuck-zero / %-of-normal / network. Add those as checklist items — highest-value
   small fix.
2. **`data_quality.md` "Known bad data inventory" table doesn't list the under-reporters.**
   Waipā / Lower Limahuli appear only in Rule 7 prose; station 0602 (Common Ground) is still tagged
   only as a *spike* station though it under-reports too. Add rows so they're catalogued, not just
   narrated.
3. **Island metadata** (`Manukā`, `Keōpukaloa` = `'Unknown'` in `mesonet_stations`) — a **database
   write**, not a doc edit; still outstanding, needs an authorized DB update separate from the docs.

None of these change the headline: the deployed rulebook now matches how I answer, and the
prescribed query reproduces the correct driest-station behavior.

## Provenance
Docs read from `/opt/hcdp/src/jetstream2/` after redeploying the 7 stale docs to
`hcdp-ai-interface@qgis-glue` commit `7748790`. Live check via `mv_daily_station_summary_qc` +
`mesonet_stations`. Read-only (beyond the completed doc redeploy).
