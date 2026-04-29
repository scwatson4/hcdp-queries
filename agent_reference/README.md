# HCDP Agent Reference

This folder contains everything a SQL agent needs to answer macro-queries against the HCDP (Hawaii Climate Data Portal) PostgreSQL database.

## Files

| File | Purpose |
|------|---------|
| `schema.md` | Full table/view schemas, indexes, relationships |
| `data_products.md` | What's in each table, temporal resolution, date ranges, row counts |
| `stations.md` | Station metadata, network types, island mapping, ID systems |
| `variables.md` | Mesonet variable reference (var_id → description, units, usage) |
| `data_quality.md` | Known bad data, sentinel codes, QC rules, stations to watch |
| `methodology.md` | Critical pitfalls: network composition bias, reference panels, how to do cross-year comparisons correctly |
| `query_patterns.md` | Reusable SQL patterns with examples for common question types |
| `geography.md` | Hawaiian geography, orographic rainfall, island areas, windward/leeward |
| `connection.md` | How to connect to the database |

## How to use

1. **Always read `data_quality.md` first** — it will save you from reporting sensor errors as weather records
2. For any cross-year comparison, read `methodology.md` — naive station averages are biased
3. Use `query_patterns.md` as a starting point, not as copy-paste — adapt to the specific question
4. Check `stations.md` when the user names a location (e.g., "Manoa") — you need to map it to a station_id
5. Use `geography.md` to interpret results — windward/leeward context matters for every rainfall question

## Database connection

```
Host: localhost
Port: 5432
Database: hcdp
User: postgres (local peer auth)
```

Use `sudo -u postgres psql -d hcdp` for interactive access, or set `HCDP_PG_DSN` for programmatic access.
