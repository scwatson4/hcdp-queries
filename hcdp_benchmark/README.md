# HCDP Text-to-SQL Benchmark

An agentic text-to-SQL benchmark built on a local PostgreSQL mirror of the Hawaii Climate Data Portal (HCDP) mesonet and historical station data.

## Authoring workflow

1. **Log a query**: `python scripts/log_query.py --question "..." --sql-file path/to/query.sql --tags rainfall,climatology`
2. **Fill in prose**: edit `narrative.md` (scientific writeup) and the metadata fields (`intent`, `scientific_context`, `reasoning_sketch`, `pitfalls`)
3. **Verify**: manually review SQL correctness and result plausibility
4. **Mark verified**: set `"verified": true` in `metadata.json`

Unfilled `_TODO_` placeholders in `narrative.md` or `review_notes.md` block verification — every entry should have real scientific context before being marked verified.

## Why the prose fields matter

- **intent**: what the question is *really* asking (disambiguates vague NL)
- **scientific_context**: domain knowledge an agent would need to answer correctly
- **reasoning_sketch**: step-by-step solution path, for evaluating agent trajectories
- **pitfalls**: common mistakes (sensor errors, spatial bias, unit confusion) that test agent robustness

These fields make the benchmark useful for evaluating *reasoning quality*, not just SQL correctness.

## Schema versioning

Schema snapshots live in `schema_snapshots/`. The current version is in `schema_snapshots/CURRENT`.

Each entry's `metadata.json` records which `schema_version` it was authored against. If the schema changes, create a new snapshot (`schema_v2.sql`) and update `CURRENT`.

## Building the HuggingFace dataset

```bash
pip install -r requirements.txt
python scripts/build_hf_dataset.py
```

Outputs to `dist/`:
- `benchmark.parquet` — columnar format for HF datasets
- `benchmark.jsonl` — one JSON object per entry
- `dataset_card.md` — HuggingFace dataset card

Only entries with `"verified": true` are included in the build. Run with no verified entries to get a preview build of all entries.

## Reproducibility

Gold results are defined against a specific schema version and data snapshot. The `as_of` timestamp in each entry records when the query was executed. A frozen `pg_dump` data snapshot will be provided in a future release for exact reproducibility.

## Data attribution

Data sourced from the [Hawaii Climate Data Portal (HCDP)](https://www.hawaii.edu/climate-data-portal/), University of Hawaii.
