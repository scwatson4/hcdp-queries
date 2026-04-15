#!/usr/bin/env python3
"""CLI to log a new benchmark entry from a natural-language question + SQL file."""

import argparse
import csv
import hashlib
import io
import json
import os
import re
import subprocess
import sys
import uuid
from datetime import datetime, timezone


def slugify(text, max_len=40):
    s = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return s[:max_len].rstrip("-")


def next_id(entries_dir):
    existing = [d for d in os.listdir(entries_dir) if os.path.isdir(os.path.join(entries_dir, d))]
    nums = []
    for d in existing:
        parts = d.rsplit("_", 1)
        if parts and parts[-1].isdigit():
            nums.append(int(parts[-1]))
    return max(nums, default=0) + 1


def run_sql(dsn, sql):
    cmd = [
        "psql", dsn, "-c",
        f"\\copy ({sql.rstrip(';')}) TO STDOUT WITH CSV HEADER",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    if result.returncode != 0:
        print(f"SQL error: {result.stderr}", file=sys.stderr)
        sys.exit(1)
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description="Log a new HCDP benchmark entry")
    parser.add_argument("--question", required=True, help="Natural-language question")
    parser.add_argument("--sql-file", required=True, help="Path to SQL file")
    parser.add_argument("--tags", default="", help="Comma-separated domain tags")
    parser.add_argument("--intent", default=None)
    parser.add_argument("--context", default=None, help="Scientific context")
    parser.add_argument("--reasoning", default=None, help="Reasoning sketch")
    parser.add_argument("--pitfalls", default=None, help="Semicolon-separated pitfalls")
    args = parser.parse_args()

    dsn = os.environ.get("HCDP_PG_DSN")
    if not dsn:
        print("Error: set HCDP_PG_DSN environment variable", file=sys.stderr)
        sys.exit(1)

    base = os.path.join(os.path.dirname(__file__), "..", "entries")
    os.makedirs(base, exist_ok=True)

    with open(args.sql_file) as f:
        sql_text = f.read()

    # Strip comments for execution (keep only the first statement)
    exec_sql = "\n".join(
        line for line in sql_text.splitlines()
        if not line.strip().startswith("--")
    ).split(";")[0].strip()

    slug = slugify(args.question)
    entry_id = next_id(base)
    date_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    dirname = f"{date_str}_{slug}_{entry_id:03d}"
    entry_dir = os.path.join(base, dirname)
    os.makedirs(entry_dir)

    # Write question.md
    with open(os.path.join(entry_dir, "question.md"), "w") as f:
        f.write(args.question + "\n")

    # Write query.sql
    with open(os.path.join(entry_dir, "query.sql"), "w") as f:
        f.write(sql_text)

    # Execute and save results
    print(f"Executing SQL against {dsn}...")
    csv_output = run_sql(dsn, exec_sql)
    results_path = os.path.join(entry_dir, "results.csv")
    with open(results_path, "w") as f:
        f.write(csv_output)

    # Parse results for metadata
    reader = csv.DictReader(io.StringIO(csv_output))
    rows = list(reader)
    canonical = json.dumps(rows, sort_keys=True)
    result_hash = hashlib.sha256(canonical.encode()).hexdigest()
    preview = rows[:10]

    # Write metadata.json
    metadata = {
        "question_id": str(uuid.uuid4()),
        "question_nl": args.question,
        "schema_version": "v1",
        "as_of": datetime.now(timezone.utc).isoformat(),
        "gold_sql": None,
        "gold_result_hash": result_hash,
        "gold_result_preview": preview,
        "draft_sql": sql_text,
        "verified": False,
        "difficulty": None,
        "domain_tags": [t.strip() for t in args.tags.split(",") if t.strip()],
        "required_tools": [],
        "evaluation_type": "execution_match",
        "timeout_s": 120,
        "max_turns": 20,
        "data_source_attribution": "HCDP - Hawaii Climate Data Portal",
        "license": "TBD",
        "notes": "",
        "intent": args.intent,
        "scientific_context": args.context,
        "reasoning_sketch": args.reasoning,
        "expected_answer_shape": None,
        "pitfalls": [p.strip() for p in args.pitfalls.split(";")] if args.pitfalls else [],
        "follow_up_questions": [],
        "assumptions": [],
    }
    with open(os.path.join(entry_dir, "metadata.json"), "w") as f:
        json.dump(metadata, f, indent=2)

    # Write template files
    with open(os.path.join(entry_dir, "answer.md"), "w") as f:
        f.write("## Answer\n_TODO_\n")

    with open(os.path.join(entry_dir, "narrative.md"), "w") as f:
        f.write("## Scientific context\n_TODO_\n\n## Methodology\n_TODO_\n\n## Key findings\n_TODO_\n\n## Limitations\n_TODO_\n")

    with open(os.path.join(entry_dir, "review_notes.md"), "w") as f:
        f.write("## Review notes\n_TODO_\n\n## Verification status\n- [ ] Cross-checked with independent source\n- [ ] SQL reviewed for correctness\n- [ ] Result magnitude sanity-checked\n")

    with open(os.path.join(entry_dir, "trajectory.jsonl"), "w") as f:
        f.write("")

    # Git add + commit
    subprocess.run(["git", "add", entry_dir], cwd=os.path.join(os.path.dirname(__file__), ".."))
    subprocess.run(
        ["git", "commit", "-m", f"Add entry: {slug}"],
        cwd=os.path.join(os.path.dirname(__file__), ".."),
    )

    print(f"\nEntry created: {dirname}")
    print(f"  {len(rows)} result rows, hash: {result_hash[:16]}...")
    print(f"  Next steps: fill in answer.md, narrative.md, then set verified=true")


if __name__ == "__main__":
    main()
