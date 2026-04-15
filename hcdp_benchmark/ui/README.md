# HCDP Benchmark Browser

A Streamlit UI for browsing every query in `hcdp_benchmark/entries/` and
all of its associated artifacts (SQL, gold results, rich metadata, prose
docs, and agent trajectory).

## Run

From the repo root:

```bash
pip install -r requirements.txt
streamlit run hcdp_benchmark/ui/app.py
```

Streamlit will print a local URL (typically <http://localhost:8501>).

## Features

- **Auto-discovery** — every folder under `entries/` with a `metadata.json`
  is picked up automatically. New queries appear within 30 seconds (or
  instantly via the **Refresh entries** button in the sidebar). No
  registration step is required.
- **Sidebar filters** — search by question text / slug, filter by verified
  status, multi-select by `domain_tags` or `difficulty`.
- **Cycling** — `◀ Previous` / `Next ▶` buttons walk the filtered list in
  order; the sidebar radio also supports click-to-jump.
- **Deep links** — the selected entry is encoded in the URL as
  `?slug=<folder-name>`, so links are shareable and reload to the same
  entry.
- **Per-entry tabs**:
  - **SQL** — syntax-highlighted `query.sql` with a download button; the
    `metadata.draft_sql` (if different) is also available.
  - **Results** — `results.csv` rendered as a sortable DataFrame, with
    row / column counts and the `gold_result_preview` / `gold_result_hash`
    from metadata.
  - **Metadata** — key reasoning fields (`intent`, `scientific_context`,
    `reasoning_sketch`, `assumptions`, `pitfalls`, `follow_up_questions`)
    surfaced in expanders; full raw JSON at the bottom.
  - **Narrative / Answer / Question / Review notes** — rendered markdown.
  - **Trajectory** — `trajectory.jsonl` as a step-by-step view or a table.
- **Authoring cues** — entries containing `_TODO_` placeholders or missing
  artifacts are flagged in the header banner so unverified work is easy
  to spot.

## File layout

```
hcdp_benchmark/ui/
├── app.py        # Streamlit entrypoint; sidebar, routing, cycling
├── loader.py     # Discovers entries and reads artifacts (with caching)
├── render.py     # Per-tab rendering helpers
└── README.md     # (this file)
```
