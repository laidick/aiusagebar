# AI Usage Bar — Implementation Plan

> **Status 2026-09-03: superseded.** Adopted `akitaonrails/ai-usagebar` (vendor/ submodule) instead of
> the own-Swift build below — it already ships Claude/Codex/Antigravity(Gemini) fetching, CLI-cred reuse,
> CLI-driven browser OAuth login, tests, and a Swift macOS menu bar app. The phase-1 scaffold lives on
> branch `feat/scaffold-core` for reference.

Clone of aiusagebar.com: native macOS menu bar app showing live usage limits for
**Claude Code, OpenAI Codex, Google Gemini CLI**.

## Constraints (verified on this machine)
- macOS 26, Swift 6.2 via Command Line Tools only (no Xcode). Build with SwiftPM;
  package `.app` bundle manually.
- XCTest unavailable. Use **swift-testing** (`import Testing`). `swift test` needs:
  `-Xswiftc -F/Library/Developer/CommandLineTools/Library/Developer/Frameworks -Xlinker -F<same> -Xlinker -rpath -Xlinker <same>`
  (wrapped in `Makefile`).
- API facts: see `docs/API-REFERENCE.md` (extracted from CodexBar / ClaudeBar / official CLIs).

## Product scope (v1)
| Feature | v1 |
|---|---|
| Menu bar: one compact gauge per provider (session % fill), click opens popover | yes |
| Popover: per provider — plan, session (5h) %, weekly (7d) %, reset countdown `↻ 1h 14m` / `6d 15h`, per-model rows (Claude model limits, Gemini per-model daily buckets, Codex extra limits), credits/extra-usage spend | yes |
| Gemini backend order: (1) Antigravity local server via `agy` CLI (reuse running same-user process, else spawn under PTY; `RetrieveUserQuotaSummary` + `GetUserStatus`), (2) Gemini Code Assist remote (`loadCodeAssist` + `retrieveUserQuota`) with Google OAuth via gemini-cli client — only works for Standard/Enterprise tiers since Google's 2026-06 consumer shutdown. See `docs/ANTIGRAVITY-REFERENCE.md`. | yes |
| Auth: reuse CLI credentials (Claude Keychain/file, `~/.codex/auth.json`, `~/.gemini/oauth_creds.json` + Keychain `gemini-cli-oauth`) | yes |
| Auth: built-in OAuth login (browser, PKCE loopback) per provider when no creds / creds invalid; tokens stored in app's own file `~/Library/Application Support/AIUsageBar/credentials.json` (0600). Never write back into CLI files. | yes |
| Token refresh for app-owned creds; CLI-owned expired creds → refresh in memory only | yes |
| Notifications at 75% and 90% (per window, once per reset cycle) | yes |
| Settings: refresh interval, provider enable/disable, launch at login, show % in menu bar | yes |
| Claude local spend (today / this month) from `~/.claude/projects/**/*.jsonl` | yes |
| Floating bar, Touch Bar, 47 providers, paid tier | no |

## Architecture
SwiftPM package `AIUsageBar`, macOS 14+.

```
Package.swift
Makefile                      build / test / bundle / run
Sources/AIUsageBarCore/       pure logic, no AppKit (testable)
  Models/   UsageSnapshot.swift (Provider, RateWindow, ModelLimit, Credits, ProviderSnapshot)
  Net/      HTTPClient.swift (protocol + URLSession impl), JWT.swift, ISO8601.swift
  Auth/     CredentialStore.swift (app-owned file store), OAuthLoopbackServer.swift (NWListener),
            PKCE.swift, KeychainReader.swift
  Providers/Claude/   ClaudeCredentials.swift, ClaudeUsageFetcher.swift, ClaudeOAuth.swift, ClaudeCostScanner.swift, ClaudePricing.swift
  Providers/Codex/    CodexCredentials.swift, CodexUsageFetcher.swift, CodexOAuth.swift
  Providers/Gemini/   GeminiCredentials.swift, GeminiUsageFetcher.swift, GeminiOAuth.swift
  Providers/ProviderService.swift  (protocol: loadCredentials, fetch, login)
  Format/   ResetFormatter.swift (`↻ 1h 14m`), Percent formatting
  Alerts/   ThresholdNotifier.swift (75/90 state machine, pure)
Sources/AIUsageBar/           AppKit + SwiftUI app
  main.swift, AppDelegate.swift, StatusItemController.swift (NSStatusItem, gauge drawing),
  PopoverView.swift, ProviderRowView.swift, SettingsView.swift, UsageCoordinator.swift (refresh loop),
  Notifications.swift (UNUserNotificationCenter), LaunchAtLogin.swift (SMAppService)
Tests/AIUsageBarCoreTests/    swift-testing; fixtures of real JSON shapes; fake HTTPClient
Resources/Info.plist          LSUIElement=true
```

Rules: immutable structs, small files (<400 lines), explicit errors, no secrets in repo
(Gemini client secret is a public installed-app secret per Google; scrape from installed CLI first, fallback constant).

## Phases
1. **Scaffold** — Package, Makefile, models, HTTPClient, JWT, ISO8601, PKCE, loopback server, CredentialStore, ResetFormatter, ThresholdNotifier + tests. (1 agent)
2. **Providers** — Claude / Codex / Gemini fetchers + credentials + OAuth, each with fixture tests. (3 agents parallel)
3. **App** — status item, popover, settings, coordinator, notifications, launch-at-login, bundle. (1 agent)
4. **Review + verify** — code review agent; `make test`; `make run`; live check with user's existing CLI creds.
5. **Live OAuth check** — prompt user to log in via browser for each provider; verify Claude authorize URL.

## Verification
- `make test` green.
- `make bundle && open build/AIUsageBar.app` shows three gauges; popover shows real numbers for Codex (auth.json present), Claude (Keychain present), Gemini (may hit consumer-tier shutdown → clear error shown).
- OAuth: each provider login opens browser, callback captured, usage fetched with new token.
