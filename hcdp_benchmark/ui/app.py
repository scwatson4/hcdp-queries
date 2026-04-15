"""Streamlit entrypoint for the HCDP benchmark query browser.

Run with:

    streamlit run hcdp_benchmark/ui/app.py

Every entry folder under ``hcdp_benchmark/entries/`` is auto-discovered on
load (30-second cache); new queries appear without any code changes.
"""

from __future__ import annotations

import streamlit as st

# Streamlit adds the script's directory to sys.path, so sibling modules
# are importable directly.
import loader
import render


def _init_page() -> None:
    st.set_page_config(
        page_title="HCDP Benchmark Browser",
        page_icon="🌺",
        layout="wide",
        initial_sidebar_state="expanded",
    )


def _render_sidebar(entries: list[dict]) -> list[dict]:
    """Render sidebar controls and return the filtered list of entries."""
    st.sidebar.title("🌺 HCDP Benchmark")
    st.sidebar.caption(f"{len(entries)} total entries")

    if st.sidebar.button("🔄 Refresh entries", use_container_width=True):
        st.cache_data.clear()
        st.rerun()

    st.sidebar.divider()
    st.sidebar.subheader("Filters")

    search = st.sidebar.text_input("Search question / slug", "")

    verified_choice = st.sidebar.radio(
        "Verified status",
        options=["All", "Verified only", "Unverified only"],
        index=0,
    )

    tags = loader.all_tags(entries)
    selected_tags = st.sidebar.multiselect("Domain tags", options=tags)

    difficulties = loader.all_difficulties(entries)
    selected_difficulties = (
        st.sidebar.multiselect("Difficulty", options=difficulties)
        if difficulties
        else []
    )

    # Apply filters
    filtered = entries
    if search:
        needle = search.lower()
        filtered = [
            e
            for e in filtered
            if needle in (e["question_nl"] or "").lower()
            or needle in e["slug"].lower()
        ]
    if verified_choice == "Verified only":
        filtered = [e for e in filtered if e["verified"]]
    elif verified_choice == "Unverified only":
        filtered = [e for e in filtered if not e["verified"]]
    if selected_tags:
        selected_set = set(selected_tags)
        filtered = [e for e in filtered if selected_set & set(e["tags"])]
    if selected_difficulties:
        filtered = [
            e for e in filtered if str(e.get("difficulty")) in selected_difficulties
        ]

    st.sidebar.divider()
    st.sidebar.subheader(f"Entries ({len(filtered)})")

    if not filtered:
        st.sidebar.info("No entries match the current filters.")
    return filtered


def _select_entry(filtered: list[dict]) -> dict | None:
    """Choose which entry to display; wire up the sidebar radio + URL param."""
    if not filtered:
        return None

    slugs = [e["slug"] for e in filtered]

    # Pick up a slug from ?slug=... if it's in the filtered set.
    params = st.query_params
    desired_slug = params.get("slug")
    default_idx = 0
    if desired_slug in slugs:
        default_idx = slugs.index(desired_slug)

    def _fmt(slug: str) -> str:
        entry = next(e for e in filtered if e["slug"] == slug)
        marker = "✅" if entry["verified"] else "◻️"
        if entry.get("has_todo"):
            marker = "⚠️"
        return f"{marker}  {entry['question_nl']}"

    chosen_slug = st.sidebar.radio(
        "Select an entry",
        options=slugs,
        index=default_idx,
        format_func=_fmt,
        label_visibility="collapsed",
        key="entry_radio",
    )

    # Keep ?slug=... in sync
    if st.query_params.get("slug") != chosen_slug:
        st.query_params["slug"] = chosen_slug

    return next(e for e in filtered if e["slug"] == chosen_slug)


def _render_cycle_controls(filtered: list[dict], current_slug: str) -> None:
    slugs = [e["slug"] for e in filtered]
    idx = slugs.index(current_slug)
    total = len(slugs)

    col_prev, col_info, col_next = st.columns([1, 2, 1])
    with col_prev:
        if st.button("◀ Previous", use_container_width=True, disabled=total <= 1):
            new_slug = slugs[(idx - 1) % total]
            st.query_params["slug"] = new_slug
            st.rerun()
    with col_info:
        st.markdown(
            f"<div style='text-align:center;padding-top:0.4em;'>Entry "
            f"<b>{idx + 1}</b> of <b>{total}</b></div>",
            unsafe_allow_html=True,
        )
    with col_next:
        if st.button("Next ▶", use_container_width=True, disabled=total <= 1):
            new_slug = slugs[(idx + 1) % total]
            st.query_params["slug"] = new_slug
            st.rerun()


def _render_entry(entry: dict) -> None:
    render.render_header(entry)
    st.divider()

    tabs = st.tabs(
        [
            "📄 SQL",
            "📊 Results",
            "🧾 Metadata",
            "📝 Narrative",
            "💡 Answer",
            "❓ Question",
            "🔍 Review notes",
            "🛤️ Trajectory",
        ]
    )
    with tabs[0]:
        render.render_sql_tab(entry)
    with tabs[1]:
        render.render_results_tab(entry)
    with tabs[2]:
        render.render_metadata_tab(entry)
    with tabs[3]:
        render.render_markdown_tab(entry, "narrative_md", "narrative.md")
    with tabs[4]:
        render.render_markdown_tab(entry, "answer_md", "answer.md")
    with tabs[5]:
        render.render_markdown_tab(entry, "question_md", "question.md")
    with tabs[6]:
        render.render_markdown_tab(entry, "review_md", "review_notes.md")
    with tabs[7]:
        render.render_trajectory_tab(entry)


def main() -> None:
    _init_page()

    entries = loader.list_entries()
    if not entries:
        st.title("🌺 HCDP Benchmark Browser")
        st.warning(
            f"No entries found under `{loader.ENTRIES_DIR}`. "
            "Add a folder there (with at least `metadata.json`) and click Refresh."
        )
        return

    filtered = _render_sidebar(entries)
    summary = _select_entry(filtered)

    if summary is None:
        st.title("🌺 HCDP Benchmark Browser")
        st.info("Adjust the filters in the sidebar to select an entry.")
        return

    _render_cycle_controls(filtered, summary["slug"])
    entry = loader.load_entry(summary["slug"])
    _render_entry(entry)


if __name__ == "__main__":
    main()
