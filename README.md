# hcdp-queries

An agentic **text-to-SQL benchmark** built on a local PostgreSQL mirror of the
[Hawaii Climate Data Portal](https://www.hawaii.edu/climate-data-portal/) (HCDP)
mesonet and historical station data. Each entry pairs a natural-language
question with its gold SQL, expected result, schema version, and rich prose
(intent, scientific context, reasoning sketch, pitfalls) that makes the
benchmark useful for evaluating *reasoning quality*, not just SQL correctness.

## 🌺 Live query browser

**[hcdp-queries.streamlit.app](https://hcdp-queries.streamlit.app/)**

[![Open in Streamlit](https://static.streamlit.io/badges/streamlit_badge_black_white.svg)](https://hcdp-queries.streamlit.app/)

Browse every query in the repo: SQL, gold results, metadata, narrative, and
the full agent trajectory — all in one place, with filters by tag, verified
status, and difficulty. New entries pushed to `main` appear automatically.

## What's in this repo

```
hcdp_benchmark/
├── entries/              # One folder per benchmark query
│   └── <date>_<slug>_<n>/
│       ├── query.sql          # PostgreSQL query
│       ├── metadata.json      # Question, tags, intent, pitfalls, gold result hash, …
│       ├── results.csv        # Gold output
│       ├── narrative.md       # Scientific writeup
│       ├── question.md        # Natural-language question
│       ├── answer.md          # Answer in prose
│       ├── review_notes.md    # Verification notes
│       └── trajectory.jsonl   # Reference agent trajectory
├── schema_snapshots/     # Versioned PostgreSQL schema dumps
├── scripts/
│   ├── log_query.py           # Authoring CLI
│   └── build_hf_dataset.py    # Exports verified entries to HuggingFace format
├── ui/                   # Streamlit query browser (deployed above)
└── README.md             # Authoring workflow & verification details
```

## Using the benchmark

- **Browse** — use the live UI above, or open any `entries/<slug>/` folder on GitHub
- **Author a new query** — see [`hcdp_benchmark/README.md`](hcdp_benchmark/README.md)
- **Build the HuggingFace dataset** — `python hcdp_benchmark/scripts/build_hf_dataset.py` (only `verified: true` entries are included)
- **Run the UI locally** — see [`hcdp_benchmark/ui/README.md`](hcdp_benchmark/ui/README.md)

## Data attribution

Data sourced from the [Hawaii Climate Data Portal](https://www.hawaii.edu/climate-data-portal/), University of Hawaii.
