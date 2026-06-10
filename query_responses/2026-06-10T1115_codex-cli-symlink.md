# Query: Install Codex CLI on Jetstream2 + wire it for the chatbot's codex mode

**Date:** 2026-06-10 11:15 UTC

The laptop chatbot invokes codex as `/home/exouser/.local/bin/codex` and passes `OPENAI_API_KEY` inline per turn. Recon revealed almost everything was already in place from prior deploys — only the stable-path symlink at `~/.local/bin/codex` was missing.

---

## Versions

| Item | Value |
|------|-------|
| `codex` binary | `codex-cli 0.130.0` |
| Real binary location | `/usr/bin/codex` |
| Symlink (chatbot's expected path) | `/home/exouser/.local/bin/codex → /usr/bin/codex` |
| Node | v22.22.2 |
| npm | 10.9.7 |
| npm global root | `/usr/lib/node_modules` |

## Install method

**Not installed by me this turn.** Codex CLI was already installed via `sudo npm install -g @openai/codex` on **2026-05-13** during the original codex deploy. The only thing this task actually changed on disk was creating the symlink at `/home/exouser/.local/bin/codex`. The `~/.local/bin/` directory itself didn't exist either — created with `mkdir -p`.

## Smoke test

```
$ /home/exouser/.local/bin/codex --version
codex-cli 0.130.0

$ /home/exouser/.local/bin/codex --help | head -5
Codex CLI

If no subcommand is specified, options will be forwarded to the interactive CLI.

Usage: codex [OPTIONS] [PROMPT]
```

## MCP entries in `~/.codex/config.toml`

All three already registered (from the prior 2026-05-26 `hcdp-tables` deploy):

```toml
[mcp_servers.hcdp-raster]
command = "/opt/hcdp/raster_service/.venv/bin/python3"
args = ["/opt/hcdp/mcp/hcdp_raster_mcp_server.py"]

[mcp_servers.hcdp-raster.env]
HCDP_RASTER_BASE_URL = "http://127.0.0.1:8000"
HCDP_RASTER_API_KEY = "<REDACTED>"

[mcp_servers.hcdp-charts]
command = "/opt/hcdp/raster_service/.venv/bin/python3"
args = ["/opt/hcdp/mcp/chart_mcp_server.py"]

[mcp_servers.hcdp-tables]
command = "/opt/hcdp/raster_service/.venv/bin/python3"
args = ["/opt/hcdp/mcp/table_mcp_server.py"]
```

Python paths and `args` are byte-identical to the corresponding `~/.claude.json` entries — both agents launch the same MCP server processes.

## Things worth flagging

1. **`~/.codex/auth.json` exists** (215 bytes, mode 600, from 2026-05-13). The task says auth comes inline from the laptop per turn, which means **the inline `OPENAI_API_KEY` will take precedence** at runtime. The stale `auth.json` won't cause incorrect behavior but isn't strictly needed. Left it alone since the task didn't ask me to remove it. Easy to delete later with `rm ~/.codex/auth.json` if you want the host truly stateless w.r.t. OpenAI auth.

2. **Codex added a few runtime-only sections to `config.toml`** since the last touch: `personality = "pragmatic"`, `[projects."/home/exouser"]`, `[projects."/home/exouser/hcdp-queries"]` (both `trust_level = "trusted"`), `[tui.model_availability_nux]`. These appeared as codex was actually used between May 13 and Jun 10. Not destructive — bookkeeping that codex maintains for project-trust prompts and one-time NUX messages. My MCP server blocks weren't touched.

3. **`npm bin -g` is no longer a valid command** in npm 9+. Recon line returned `Unknown command: "bin"`. Not a problem here — global install path is still discoverable via `npm root -g` (`/usr/lib/node_modules`). FYI if other scripts depend on `npm bin -g`.

4. **`/home/exouser/.local/bin/` didn't exist.** `mkdir -p` handled it. The companion CLI `claude` does already live there, so this is a previously-established convention; just hadn't been populated with `codex`.
