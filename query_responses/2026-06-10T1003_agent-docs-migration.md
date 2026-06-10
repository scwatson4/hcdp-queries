# Query: Migrate agent docs from hcdp-queries into hcdp-ai-interface (jetstream2/)

**Date:** 2026-06-10 10:03 UTC
**Branch:** `claude/integrate-pipeline-codex-OMPo2`
**HEAD after migration:** `39c0d21` ("Import agent docs from hcdp-queries (pristine)")

Imported the live agent docs (`CLAUDE.md` + `agent_reference/*`) from the `hcdp-queries` repo into the version-controlled `jetstream2/` subtree of `hcdp-ai-interface`. Then set up a scratch workdir at `~/hcdp-workdir/` with symlinks back to the version-controlled copies, so the laptop chatbot's `JETSTREAM2_*_WORKDIR` can point to one stable location backed by source-of-truth files in git.

`~/hcdp-queries/` was not modified — it stays as the archive of past query responses.

---

## Files imported (12)

```
jetstream2/CLAUDE.md                          ← ~/hcdp-queries/CLAUDE.md
jetstream2/agent_reference/README.md          ← ~/hcdp-queries/agent_reference/README.md
jetstream2/agent_reference/connection.md      ← …/connection.md
jetstream2/agent_reference/data_products.md   ← …/data_products.md
jetstream2/agent_reference/data_quality.md    ← …/data_quality.md
jetstream2/agent_reference/geography.md       ← …/geography.md
jetstream2/agent_reference/methodology.md     ← …/methodology.md
jetstream2/agent_reference/query_patterns.md  ← …/query_patterns.md
jetstream2/agent_reference/response_style.md  ← …/response_style.md
jetstream2/agent_reference/schema.md          ← …/schema.md
jetstream2/agent_reference/stations.md        ← …/stations.md
jetstream2/agent_reference/variables.md       ← …/variables.md
```

Pristine — `cp` only, no edits. Editorial updates are explicitly deferred to laptop-side where they can be reviewed.

No collision with the pre-existing `jetstream2/agent_reference/raster_recipes.md` (no such file in the source). All 12 untracked-then-added; none were `.gitignore`'d.

## Push result

- **Commit:** `39c0d21` — "Import agent docs from hcdp-queries (pristine)"
- **Pushed to:** `origin/claude/integrate-pipeline-codex-OMPo2` (fast-forward `f40cc70..39c0d21`)
- **Auth:** push succeeded under the existing PAT remote — not a deploy-key situation

## One snag, resolved

The initial commit failed with `fatal: empty ident name not allowed` because git identity wasn't set in this checkout. Set `user.email=scwatson4@users.noreply.github.com` and `user.name=scwatson4` **locally to this repo only** (`git config`, not `git config --global`) — same handling used for `hcdp-queries` earlier. This is identity, not auth, so it doesn't conflict with the "don't work around auth" constraint.

## Workdir verification

```
$ ls -la ~/hcdp-workdir
lrwxrwxrwx  AGENTS.md       → /opt/hcdp/src/jetstream2/AGENTS.md
lrwxrwxrwx  CLAUDE.md       → /opt/hcdp/src/jetstream2/CLAUDE.md
lrwxrwxrwx  agent_reference → /opt/hcdp/src/jetstream2/agent_reference

$ head -5 ~/hcdp-workdir/CLAUDE.md
# HCDP query environment

You have direct read access to the HCDP Postgres database. Connect with:
sudo -u postgres psql -d hcdp -c "..."
```

All three symlinks resolve. `~/hcdp-workdir/agent_reference/` lists 12 files (the 11 imported + the pre-existing `raster_recipes.md`).

## Side-effects (none destructive)

- `~/hcdp-queries/` untouched — remains the archive of past query responses.
- `~/.gitconfig` untouched — identity was set only inside `/opt/hcdp/src/.git/config`.
- The chatbot's `JETSTREAM2_CLAUDE_WORKDIR` / `JETSTREAM2_CODEX_WORKDIR` need to be repointed from `/home/exouser/hcdp-queries` to `/home/exouser/hcdp-workdir` on the laptop side for this to take effect. That's a `.env` edit on the laptop, not on this host.

## What this means for ongoing work

- **Source of truth for agent docs now lives in `hcdp-ai-interface`** under `jetstream2/`. PRs that change agent behavior go through code review like any other change.
- **`hcdp-queries` becomes purely the response log + benchmark + golden queries**, as discussed in the earlier "should we host agent files in hcdp-ai-interface?" conversation.
- **Codex CLI now gets the same `AGENTS.md` as Claude does CLAUDE.md** — both are in `jetstream2/` and both end up symlinked into `~/hcdp-workdir/`. The "codex has no project context" gap noted in prior deploy reports is closed once the chatbot's workdir env vars are repointed.
