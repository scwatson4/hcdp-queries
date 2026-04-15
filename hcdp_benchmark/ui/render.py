"""Per-tab rendering helpers for the HCDP benchmark UI.

All helpers take a fully loaded entry dict (see ``loader.load_entry``) and
render a section of the Streamlit page. Each one tolerates missing or
malformed artifacts by showing an informational / error message rather
than raising.
"""

from __future__ import annotations

import json
from typing import Any

import pandas as pd
import streamlit as st


# Rich-text metadata fields that deserve their own expander at the top of
# the Metadata tab. Remaining fields go into the raw JSON dump.
PROSE_FIELDS: list[tuple[str, str]] = [
    ("intent", "Intent"),
    ("scientific_context", "Scientific context"),
    ("reasoning_sketch", "Reasoning sketch"),
    ("expected_answer_shape", "Expected answer shape"),
    ("assumptions", "Assumptions"),
    ("pitfalls", "Pitfalls"),
    ("follow_up_questions", "Follow-up questions"),
    ("notes", "Notes"),
]


def render_header(entry: dict) -> None:
    md = entry.get("metadata") or {}
    question = md.get("question_nl") or entry["slug"]
    st.title(question)

    badges: list[str] = []
    if md.get("verified"):
        badges.append(":green[✅ verified]")
    else:
        badges.append(":red[❌ unverified]")
    if md.get("difficulty"):
        badges.append(f":violet[difficulty: {md['difficulty']}]")
    if md.get("as_of"):
        badges.append(f":gray[as of {md['as_of']}]")
    qid = md.get("question_id")
    if qid:
        badges.append(f":gray[id: {qid[:8]}…]")
    st.markdown(" · ".join(badges))

    tags = md.get("domain_tags") or []
    if tags:
        st.caption("Tags: " + ", ".join(f"`{t}`" for t in tags))
    st.caption(f"Slug: `{entry['slug']}`")

    # Warnings
    if entry.get("has_todo"):
        st.warning(
            "This entry contains `_TODO_` placeholders — authoring is incomplete."
        )
    if entry.get("errors"):
        msgs = "\n".join(f"- **{k}**: {v}" for k, v in entry["errors"].items())
        st.error(f"Some artifacts failed to load:\n\n{msgs}")


def render_sql_tab(entry: dict) -> None:
    sql = entry.get("sql")
    if sql is None:
        st.info("No `query.sql` in this entry.")
        return
    st.code(sql, language="sql")
    st.download_button(
        "Download query.sql",
        data=sql,
        file_name=f"{entry['slug']}.sql",
        mime="text/plain",
    )

    draft = (entry.get("metadata") or {}).get("draft_sql")
    if draft and draft.strip() and draft.strip() != sql.strip():
        with st.expander("Draft SQL (from metadata.draft_sql)"):
            st.code(draft, language="sql")


def render_results_tab(entry: dict) -> None:
    df: pd.DataFrame | None = entry.get("results_df")
    if df is None:
        st.info("No `results.csv` in this entry.")
    else:
        st.caption(f"{len(df)} rows × {len(df.columns)} columns")
        st.dataframe(df, use_container_width=True)

    md = entry.get("metadata") or {}
    preview = md.get("gold_result_preview")
    if preview:
        with st.expander("Gold result preview (from metadata)"):
            st.json(preview)
    ghash = md.get("gold_result_hash")
    if ghash:
        st.caption(f"gold_result_hash: `{ghash}`")


def _render_prose_value(value: Any) -> None:
    if isinstance(value, list):
        for item in value:
            st.markdown(f"- {item}")
    elif isinstance(value, dict):
        st.json(value)
    else:
        st.markdown(str(value))


def render_metadata_tab(entry: dict) -> None:
    md = entry.get("metadata")
    if not md:
        st.info("No `metadata.json` in this entry.")
        return

    # Highlight key reasoning fields first.
    shown: set[str] = set()
    for key, label in PROSE_FIELDS:
        if key in md and md[key] not in (None, "", [], {}):
            with st.expander(label, expanded=key in {"intent", "scientific_context"}):
                _render_prose_value(md[key])
            shown.add(key)

    # Compact facts block
    facts_keys = [
        "schema_version",
        "evaluation_type",
        "required_tools",
        "timeout_s",
        "max_turns",
        "data_source_attribution",
        "license",
    ]
    facts = {k: md[k] for k in facts_keys if k in md}
    if facts:
        with st.expander("Run configuration"):
            st.json(facts)
        shown.update(facts_keys)

    with st.expander("Full metadata.json (raw)"):
        st.json(md)


def render_markdown_tab(entry: dict, key: str, label: str) -> None:
    text = entry.get(key)
    if not text:
        st.info(f"`{label}` not authored yet.")
        return
    if "_TODO_" in text:
        st.warning("This document contains `_TODO_` placeholders.")
    st.markdown(text)


def render_trajectory_tab(entry: dict) -> None:
    traj = entry.get("trajectory")
    if not traj:
        st.info("No `trajectory.jsonl` in this entry.")
        return

    st.caption(f"{len(traj)} step(s)")
    mode = st.radio(
        "View",
        options=["Step-by-step", "Table"],
        horizontal=True,
        key=f"traj-mode-{entry['slug']}",
    )

    if mode == "Table":
        try:
            st.dataframe(pd.DataFrame(traj), use_container_width=True)
        except ValueError:
            # Rows with heterogeneous shapes — fall back to JSON list
            st.json(traj)
        return

    for i, step in enumerate(traj, 1):
        title_parts = [f"Step {step.get('turn', i)}"]
        if "tool_name" in step:
            title_parts.append(f"· {step['tool_name']}")
        with st.expander(" ".join(title_parts), expanded=i == 1):
            st.json(step)
