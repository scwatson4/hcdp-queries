"""Entry discovery and parsing for the HCDP benchmark UI.

Each entry is a folder under ``hcdp_benchmark/entries/`` containing a fixed
set of artifacts (SQL, CSV, metadata JSON, several markdown files, and a
JSONL agent trajectory). The UI scans this directory on every call (with a
short cache TTL) so that newly authored entries automatically appear
without any manual registration.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pandas as pd
import streamlit as st

ENTRIES_DIR = Path(__file__).resolve().parents[1] / "entries"

# Files Claude should try to read from each entry folder.
MARKDOWN_FILES = {
    "narrative_md": "narrative.md",
    "answer_md": "answer.md",
    "question_md": "question.md",
    "review_md": "review_notes.md",
}

TODO_MARKER = "_TODO_"


def _read_text(path: Path) -> tuple[str | None, str | None]:
    """Read a text file, returning (content, error)."""
    if not path.exists():
        return None, None
    try:
        return path.read_text(encoding="utf-8"), None
    except OSError as exc:
        return None, f"Failed to read {path.name}: {exc}"


def _read_json(path: Path) -> tuple[dict | None, str | None]:
    if not path.exists():
        return None, None
    try:
        return json.loads(path.read_text(encoding="utf-8")), None
    except (OSError, json.JSONDecodeError) as exc:
        return None, f"Failed to parse {path.name}: {exc}"


def _read_csv(path: Path) -> tuple[pd.DataFrame | None, str | None]:
    if not path.exists():
        return None, None
    try:
        return pd.read_csv(path), None
    except (OSError, pd.errors.ParserError, ValueError) as exc:
        return None, f"Failed to parse {path.name}: {exc}"


def _read_jsonl(path: Path) -> tuple[list[dict] | None, str | None]:
    if not path.exists():
        return None, None
    try:
        rows: list[dict] = []
        for i, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError as exc:
                return None, f"Malformed JSON on line {i} of {path.name}: {exc}"
        return rows, None
    except OSError as exc:
        return None, f"Failed to read {path.name}: {exc}"


def _has_todo(*blobs: Any) -> bool:
    for b in blobs:
        if isinstance(b, str) and TODO_MARKER in b:
            return True
        if isinstance(b, dict) and _has_todo(*b.values()):
            return True
        if isinstance(b, list) and _has_todo(*b):
            return True
    return False


@st.cache_data(ttl=30)
def list_entries() -> list[dict]:
    """Return a summary for every entry, sorted newest-first by slug."""
    if not ENTRIES_DIR.exists():
        return []

    summaries: list[dict] = []
    for meta_path in sorted(ENTRIES_DIR.glob("*/metadata.json")):
        entry_dir = meta_path.parent
        slug = entry_dir.name
        metadata, err = _read_json(meta_path)
        if metadata is None:
            summaries.append(
                {
                    "slug": slug,
                    "path": str(entry_dir),
                    "question_nl": f"[unparseable metadata] {slug}",
                    "verified": False,
                    "tags": [],
                    "difficulty": None,
                    "as_of": None,
                    "has_todo": False,
                    "load_error": err,
                }
            )
            continue

        summaries.append(
            {
                "slug": slug,
                "path": str(entry_dir),
                "question_nl": metadata.get("question_nl") or slug,
                "verified": bool(metadata.get("verified")),
                "tags": list(metadata.get("domain_tags") or []),
                "difficulty": metadata.get("difficulty"),
                "as_of": metadata.get("as_of"),
                "has_todo": _has_todo(metadata),
                "load_error": None,
            }
        )

    # Newest first: slugs are date-prefixed (YYYY-MM-DD_...), so reverse-lex works.
    summaries.sort(key=lambda s: s["slug"], reverse=True)
    return summaries


@st.cache_data(ttl=30)
def load_entry(slug: str) -> dict:
    """Load every artifact for a single entry. Missing files are tolerated."""
    entry_dir = ENTRIES_DIR / slug
    errors: dict[str, str] = {}

    sql, err = _read_text(entry_dir / "query.sql")
    if err:
        errors["query.sql"] = err

    results_df, err = _read_csv(entry_dir / "results.csv")
    if err:
        errors["results.csv"] = err

    metadata, err = _read_json(entry_dir / "metadata.json")
    if err:
        errors["metadata.json"] = err

    markdowns: dict[str, str | None] = {}
    for key, fname in MARKDOWN_FILES.items():
        text, err = _read_text(entry_dir / fname)
        markdowns[key] = text
        if err:
            errors[fname] = err

    trajectory, err = _read_jsonl(entry_dir / "trajectory.jsonl")
    if err:
        errors["trajectory.jsonl"] = err

    entry = {
        "slug": slug,
        "path": str(entry_dir),
        "sql": sql,
        "results_df": results_df,
        "metadata": metadata,
        "trajectory": trajectory,
        "errors": errors,
        **markdowns,
    }
    entry["has_todo"] = _has_todo(metadata, *markdowns.values())
    return entry


def all_tags(entries: list[dict]) -> list[str]:
    seen: set[str] = set()
    for e in entries:
        seen.update(e.get("tags") or [])
    return sorted(seen)


def all_difficulties(entries: list[dict]) -> list[str]:
    seen: set[str] = set()
    for e in entries:
        d = e.get("difficulty")
        if d:
            seen.add(str(d))
    return sorted(seen)
