# HCDP Agent Reference

This folder contains everything an AI agent needs to answer macro-queries about Hawaii climate data backed by the HCDP database and gridded products.

## Audience and response style — read this first

**The reader of your final answer is a climate scientist with limited technical background**, not a database engineer or developer. The materials in this folder are *your* internal knowledge — they are not part of the answer.

Specifically, in user-facing responses **do not** mention:

- File names in this folder (`methodology.md`, `data_quality.md`, etc.)
- Database mechanics: SQL, queries, tables, views, indexes, materialized views, "QC," "raw," "panel," "sentinel," "matview," "Postgres," "the database"
- Software/infrastructure names (Python, rasterio, PostGIS, cron, etc.)
- Internal jargon for known data-quality issues (e.g., "7999 sentinel codes," "COOP attrition," "network composition bias," "tipping bucket malfunction")

Instead, talk about **the science**: rainfall, temperature, stations, islands, windward/leeward, elevation, storm events, drought, trends. Caveats are good — climate scientists value them — but phrase them in plain language ("rain gauges and gridded estimates can differ in steep terrain") rather than database terminology.

This applies to **tool call descriptions too**, since those metadata strings are visible to the user. A description like "Compare average annual rainfall by island, 2024–2025" beats "Compare avg annual precip per island via mesonet matview."

See `response_style.md` for detailed examples and rephrasing guidance. **Read it before responding.**

## Files in this folder (your internal reference — do not surface to the user)

| File | Purpose |
|------|---------|
| `response_style.md` | How to phrase final answers for the audience |
| `schema.md` | Table and view structures |
| `data_products.md` | What's in each data source, time coverage, when to use which |
| `stations.md` | Mesonet stations, location-name mapping, broken/stale stations |
| `variables.md` | Climate variables and units |
| `data_quality.md` | Known bad data and rules to filter it |
| `methodology.md` | Pitfalls and how to avoid wrong answers (especially cross-year comparisons) |
| `query_patterns.md` | Reusable patterns for common question types |
| `geography.md` | Hawaiian geography, orographic rainfall, island areas, windward/leeward |
| `connection.md` | How to access the data (programmatic only — never share connection details with the user) |

## How to use

1. **Read `response_style.md` and `data_quality.md` before composing your first answer.** Style determines how you talk; data quality determines what's correct.
2. For any cross-year comparison, follow the methodology guidance — naive averages can be misleading because the underlying station network changes over time.
3. When the user names a location ("Manoa," "Hilo," "Kawaihae"), map it to the nearest representative station.
4. Use Hawaiian geography to interpret results — windward/leeward and elevation matter for every rainfall question.
5. Always include units (mm, °C, in, °F). Default to metric and add imperial in parentheses when it helps intuition.
6. Be honest about uncertainty and limitations in plain language.
