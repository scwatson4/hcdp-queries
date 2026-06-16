# Query: Switch Claude to the 1M-context Opus 4.8 and set effort to the highest

**Date:** 2026-06-16 01:10 UTC
**Scope:** only `~/.claude/settings.json`. No other files, services, or credentials touched.
Both the model id and effort key were verified against the live CLI before committing.

---

## Changes

`~/.claude/settings.json` is now:

```json
{
  "skipDangerousModePermissionPrompt": true,
  "model": "claude-opus-4-8[1m]",
  "effort": "max"
}
```

- **Model → `claude-opus-4-8[1m]`** — the 1M-context variant of Opus 4.8.
- **Effort → `max`** — the highest tier Claude offers.
- **Backup:** `~/.claude/settings.json.20260616T010324Z.bak` (prior: `claude-opus-4-8`, no effort key).

## Verification

**1M model accepted + active as default** (no `--model` flag, so it reads settings.json):
```
claude -p --output-format stream-json --verbose 'reply with OK'
→ init event:  "model":"claude-opus-4-8[1m]"
→ result:      "OK"  (is_error: false)
→ billed under: claude-opus-4-8[1m]
```

**`effort` is a real, honored settings key** (not silently ignored). Verified three ways:
- Claude's valid effort tiers: `low, medium, high, xhigh, max` (`--effort` flag help). `max` is the top.
- `"effort"` appears in the settings-schema cluster in the CLI binary alongside `model`,
  `permissions`, `statusLine`, `outputStyle` — i.e. it's a recognized settings key.
- The binary contains explicit logic strings like *"Cleared effort from settings"* and
  *"Default effort level for sessions"* — confirming settings.json `effort` is read and applied.

  (Note: this CLI **silently ignores** unknown settings keys — it did not warn on a deliberately
  bogus test key — so "no warning" alone wasn't proof; the schema/logic strings are.)

## Should we use the `[1m]` (1M-context) version? — yes, with one caveat

**Recommended for this host.** The sessions driven here are large and multi-phase
(infrastructure work, long tool transcripts), so the 1M context window meaningfully reduces
context exhaustion / compaction versus the standard 200K.

**Caveat — cost.** Long-context (>200K tokens) requests on the 1M tier bill at premium
per-token rates. For short climate-Q&A turns this is irrelevant (you only pay the premium
once a request actually exceeds 200K), but be aware heavy long-context use costs more.
If you'd rather cap cost, drop back to `claude-opus-4-8` (200K) — one-line change.

## How effort takes effect

- `settings.json` `"effort": "max"` is the **persistent default** for sessions on this host.
- It can be overridden per-session by the `--effort <level>` flag or the
  `CLAUDE_CODE_EFFORT_LEVEL` env var. If the chatbot backend wants to *guarantee* max effort
  regardless of settings, it can pass `--effort max` explicitly — but with this settings.json
  it's already the default.

## Codex (unchanged, for completeness)

Codex remains `gpt-5.5-pro` at `xhigh` (its ceiling — codex has no `max` tier). No change this round.

## Untouched

qgis-mcp service, raster service, env files, MCP tool allowlist, credentials — not modified.
Only `~/.claude/settings.json` changed.
