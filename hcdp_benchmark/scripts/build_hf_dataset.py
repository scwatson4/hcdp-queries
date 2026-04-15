#!/usr/bin/env python3
"""Build a HuggingFace-compatible dataset from verified benchmark entries."""

import csv
import io
import json
import os
import sys

import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq


ENTRIES_DIR = os.path.join(os.path.dirname(__file__), "..", "entries")
DIST_DIR = os.path.join(os.path.dirname(__file__), "..", "dist")


def read_file(path):
    if os.path.exists(path):
        with open(path) as f:
            return f.read().strip()
    return None


def load_entries(verified_only=True):
    entries = []
    for dirname in sorted(os.listdir(ENTRIES_DIR)):
        entry_dir = os.path.join(ENTRIES_DIR, dirname)
        if not os.path.isdir(entry_dir):
            continue

        meta_path = os.path.join(entry_dir, "metadata.json")
        if not os.path.exists(meta_path):
            continue

        with open(meta_path) as f:
            meta = json.load(f)

        if verified_only and not meta.get("verified"):
            continue

        # Read content files
        question_md = read_file(os.path.join(entry_dir, "question.md"))
        query_sql = read_file(os.path.join(entry_dir, "query.sql"))
        answer_md = read_file(os.path.join(entry_dir, "answer.md"))
        narrative_md = read_file(os.path.join(entry_dir, "narrative.md"))

        # Read results as JSON array
        results_path = os.path.join(entry_dir, "results.csv")
        results_json = None
        if os.path.exists(results_path):
            with open(results_path) as f:
                reader = csv.DictReader(f)
                results_json = json.dumps(list(reader))

        row = {
            **meta,
            "question_text": question_md,
            "query_sql": query_sql,
            "answer_text": answer_md,
            "narrative": narrative_md,
            "results_json": results_json,
            "gold_result_preview": json.dumps(meta.get("gold_result_preview")),
            "domain_tags": json.dumps(meta.get("domain_tags", [])),
            "required_tools": json.dumps(meta.get("required_tools", [])),
            "pitfalls": json.dumps(meta.get("pitfalls", [])),
            "follow_up_questions": json.dumps(meta.get("follow_up_questions", [])),
            "assumptions": json.dumps(meta.get("assumptions", [])),
        }
        entries.append(row)

    return entries


def write_dataset_card(dist_dir, n_entries):
    card = f"""---
license: other
task_categories:
  - text2text-generation
  - question-answering
tags:
  - climate
  - sql
  - benchmark
  - hawaii
pretty_name: HCDP Text-to-SQL Benchmark
---

# HCDP Text-to-SQL Benchmark

An agentic text-to-SQL benchmark built on the Hawaii Climate Data Portal (HCDP) mesonet
and historical station data.

## Dataset Description

- **Entries**: {n_entries} verified benchmark questions
- **Source**: HCDP PostgreSQL mirror (schema version v1)
- **Data Attribution**: Hawaii Climate Data Portal (HCDP) - https://www.hawaii.edu/climate-data-portal/

## Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `question_id` | string | Stable UUID | `"a1b2c3d4-..."` |
| `question_nl` | string | Natural-language question | `"What is the driest station?"` |
| `question_text` | string | Full question.md content | (same or elaborated) |
| `schema_version` | string | DDL snapshot version | `"v1"` |
| `as_of` | string | ISO8601 timestamp of query execution | `"2026-04-15T00:15:00Z"` |
| `gold_sql` | string/null | Verified SQL (null if unverified) | `"SELECT ..."` |
| `draft_sql` | string | SQL as initially written | `"SELECT ..."` |
| `query_sql` | string | Full query.sql file content | `"-- comment\\nSELECT ..."` |
| `gold_result_hash` | string | SHA256 of canonical result rows | `"ab12cd34..."` |
| `gold_result_preview` | json | First 10 result rows as JSON | `[{{"station": "0254"}}]` |
| `results_json` | json | Full result set as JSON array | `[...]` |
| `answer_text` | string | Short narrative answer | `"Kawaihae at 353mm/yr"` |
| `narrative` | string | Long-form scientific writeup | (prose) |
| `verified` | bool | Whether SQL + results are human-verified | `true` |
| `difficulty` | string/null | Estimated difficulty tier | `"hard"` |
| `domain_tags` | json | Topic labels | `["rainfall", "climatology"]` |
| `required_tools` | json | Tools needed beyond SQL | `["sql_query", "api_call"]` |
| `evaluation_type` | string | How to evaluate answers | `"execution_match"` |
| `timeout_s` | int | Max seconds for SQL execution | `120` |
| `max_turns` | int | Max agent turns allowed | `20` |
| `intent` | string/null | What the question is really asking | `"Identify driest location"` |
| `scientific_context` | string/null | Domain knowledge needed | `"Orographic rainfall..."` |
| `reasoning_sketch` | string/null | Step-by-step solution outline | `"1. Join tables 2. Filter..."` |
| `expected_answer_shape` | string/null | What the result should look like | `"Ranked table of 10 stations"` |
| `pitfalls` | json | Common mistakes | `["Sparse data bias"]` |
| `follow_up_questions` | json | Related questions | `["What about the wettest?"]` |
| `assumptions` | json | Assumptions made in the answer | `["Land area = 16627 km²"]` |

## Reproducibility

Gold results are defined against `schema_v1` (see `schema_snapshots/schema_v1.sql`).
Results depend on the data snapshot at `as_of` time. A frozen `pg_dump` data snapshot
will be provided in a future release for exact reproducibility.

## License

TBD. HCDP data is provided by the University of Hawaii.
"""
    with open(os.path.join(dist_dir, "dataset_card.md"), "w") as f:
        f.write(card)


def main():
    os.makedirs(DIST_DIR, exist_ok=True)

    entries = load_entries(verified_only=True)

    if not entries:
        print("No verified entries found. Set verified=true in metadata.json to include entries.")
        print("Building with ALL entries for preview...")
        entries = load_entries(verified_only=False)

    if not entries:
        print("No entries found at all.")
        sys.exit(1)

    print(f"Building dataset with {len(entries)} entries...")

    df = pd.DataFrame(entries)

    # Write parquet
    pq.write_table(pa.Table.from_pandas(df), os.path.join(DIST_DIR, "benchmark.parquet"))
    print(f"  Written: dist/benchmark.parquet")

    # Write JSONL
    with open(os.path.join(DIST_DIR, "benchmark.jsonl"), "w") as f:
        for _, row in df.iterrows():
            f.write(json.dumps(row.to_dict(), default=str) + "\n")
    print(f"  Written: dist/benchmark.jsonl")

    # Write dataset card
    write_dataset_card(DIST_DIR, len(entries))
    print(f"  Written: dist/dataset_card.md")

    print(f"\nDone. {len(entries)} entries exported.")


if __name__ == "__main__":
    main()
