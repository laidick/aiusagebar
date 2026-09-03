# aiusagebar (macOS)

macOS menu bar app showing live usage limits for **Claude Code**, **OpenAI Codex**, and
**Gemini** (via Google Antigravity) — a clone of aiusagebar.com built on
[akitaonrails/ai-usagebar](https://github.com/akitaonrails/ai-usagebar) (Rust backend + Swift menu bar UI),
vendored as a git submodule pinned to `v1.10.0`.

## Quick start

```bash
make install   # builds Rust backend (cargo) + Swift menu bar app, installs to ~/.cargo/bin and bin/
make config    # writes ~/.config/ai-usagebar/config.toml (Claude, Codex, Antigravity enabled)
make run       # starts the menu bar app
make status    # prints usage for all vendors in the terminal
make test      # cargo test + Swift logic tests
```

## Authentication (browser OAuth)

The app reads credentials the official CLIs already wrote; nothing is stored separately.

| Provider | Credential source | Log in |
|---|---|---|
| Claude | macOS Keychain `Claude Code-credentials` (or `~/.claude/.credentials.json`) | Preferences → Vendors → Log in, or `make login-claude` |
| Codex | `~/.codex/auth.json` | Preferences → Vendors → Log in, or `make login-codex` |
| Gemini | Antigravity local server (`agy` CLI or Antigravity app) | sign in inside `agy` / Antigravity once |

Google shut down Gemini CLI Code Assist OAuth for individual accounts (2026-06) — Gemini quota is
only reachable through Antigravity now. See `docs/ANTIGRAVITY-REFERENCE.md`.

## Docs
- `docs/PLAN.md` — original plan (own Swift implementation; superseded by adopting ai-usagebar)
- `docs/API-REFERENCE.md` — Claude / Codex / Gemini usage + OAuth endpoints, verified 2026-09-03
- `docs/ANTIGRAVITY-REFERENCE.md` — Antigravity local + remote quota paths
