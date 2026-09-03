# aiusagebar (macOS)

macOS menu bar app showing live usage limits for **Claude Code**, **OpenAI Codex**, and
**Gemini** (via Google Antigravity).

The **UI is ours** — a compact English SwiftPM/AppKit+SwiftUI menu bar app in `Sources/`.
The **data** comes from the Rust backend of
[akitaonrails/ai-usagebar](https://github.com/akitaonrails/ai-usagebar), vendored as a git
submodule pinned to `v1.10.0`, invoked as `ai-usagebar usage --json`. The upstream Swift UI
is no longer built.

The menu bar shows only a small severity-tinted gauge ring. Clicking it opens a 360pt popover
with a Vendor | Plan | Session | Weekly table; right-clicking gives Refresh / Log in ▸ /
Launch at login / Quit.

## Quick start

```bash
make install   # builds the Rust backend into ~/.cargo/bin, then bundles our app
make config    # writes ~/.config/ai-usagebar/config.toml (Claude, Codex, Antigravity enabled)
make run       # (re)bundles and launches "build/AI Usage Bar.app"
make dump      # one backend fetch, printed as a text lane table (no UI)
make status    # prints usage for all vendors in the terminal
make test-app  # swift-testing suite for the pure logic in AIUsageBarCore
make test      # cargo test + test-app
```

## Layout

| Path | What |
|---|---|
| `Sources/AIUsageBarCore` | Pure logic: JSON models, `LaneBuilder`, `ResetFormatter`, severity, backend runner |
| `Sources/AIUsageBar` | AppKit status item + SwiftUI popover |
| `Tests/AIUsageBarCoreTests` | swift-testing suite over `Tests/Fixtures/usage.json` |
| `Resources/Info.plist` | `LSUIElement`, bundle id `com.dicklai.aiusagebar` |
| `vendor/ai-usagebar` | Upstream Rust backend (submodule, not modified) |

Tests need the Command Line Tools frameworks on the search path; `make test-app` passes the
required `-Xswiftc -F… -Xlinker …` flags for you.

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

## Credits & references

This project stands on other people's work. Thank you.

- **[akitaonrails/ai-usagebar](https://github.com/akitaonrails/ai-usagebar)** (MIT, Fabio Akita) — the Rust backend
  that does all credential reading, token refresh, and quota fetching. Vendored unmodified as a git submodule;
  our Swift UI only consumes its `usage --json` output.
- **[mryll/claudebar](https://github.com/mryll/claudebar)** and **[mryll/codexbar](https://github.com/mryll/codexbar)** —
  origin of ai-usagebar and of the Claude / Codex OAuth endpoint references.
- **[steipete/CodexBar](https://github.com/steipete/CodexBar)** (MIT, Peter Steinberger) — source of most facts in
  `docs/API-REFERENCE.md` and `docs/ANTIGRAVITY-REFERENCE.md` (usage endpoints, headers, response shapes, Antigravity
  local-server protocol, `agy` discovery). Studied, not copied.
- **[tddworks/ClaudeBar](https://github.com/tddworks/ClaudeBar)** — Claude OAuth usage probe and 429 `Retry-After: 0`
  pitfall.
- **[openai/codex](https://github.com/openai/codex)** (`codex-rs/login`) — Codex OAuth login parameters.
- **[google-gemini/gemini-cli](https://github.com/google-gemini/gemini-cli)** (`code_assist/oauth2.ts`) — Gemini CLI
  OAuth parameters and Code Assist endpoints.
- **[aiusagebar.com](https://www.aiusagebar.com/)** — the product this app imitates (menu bar gauge + per-provider
  session/weekly limits). No code or assets were taken from it.

Provider APIs used are undocumented/internal (`api.anthropic.com/api/oauth/usage`, `chatgpt.com/backend-api/wham/usage`,
Antigravity `exa.language_server_pb`) and may change without notice.

## License

MIT — see `LICENSE`. The vendored `vendor/ai-usagebar` keeps its own MIT license.
