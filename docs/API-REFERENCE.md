# Provider Usage/Quota API Reference

Extracted from source. All citations are `path:line` relative to the clone roots below.

Clone roots (already on disk):

```
/private/tmp/claude-501/-Users-dicklai-dev-source-aiusagebar/2562fe02-c61b-45cc-a11a-85d3cf34d595/scratchpad/research/
├── CodexBar/     (github.com/steipete/CodexBar, depth 1)
├── ClaudeBar/    (github.com/tddworks/ClaudeBar, depth 1)
├── codex-cli/    (github.com/openai/codex, sparse: codex-rs/login)
└── gemini-cli/   (github.com/google-gemini/gemini-cli, sparse: packages/core/src/code_assist, config, utils)
```

**Headline finding on login:** neither CodexBar nor ClaudeBar implements an OAuth login flow for
Claude, Codex, or Gemini. Both read the credentials the official CLIs already wrote. CodexBar's only
"login" for Claude is driving the CLI in a PTY: `claude auth login --claudeai`
(`CodexBar/Sources/CodexBar/ClaudeLoginRunner.swift:6`). The single provider where CodexBar does run
its own OAuth is Antigravity (`CodexBar/Sources/CodexBar/Providers/Antigravity/AntigravityLoginRunner.swift:122`).
Official CLI OAuth parameters are in section 4.

---

## 1. Claude Code

### 1a. Credentials on disk / Keychain

| What | Value | Cite |
|---|---|---|
| Keychain service | `Claude Code-credentials` | `CodexBar/Sources/CodexBarCore/Providers/Claude/ClaudeOAuth/ClaudeOAuthCredentials.swift:15` |
| Keychain class | `kSecClassGenericPassword` | same file `:2386` |
| File fallback | `~/.claude/.credentials.json` | `.../Claude/ClaudeConfigPaths.swift:49`, `.../ClaudeOAuthCredentials.swift:2942` |
| Config dir override | `CLAUDE_CONFIG_DIR` | `ClaudeConfigPaths.swift:5` |
| Secure-storage dir override | `CLAUDE_SECURESTORAGE_CONFIG_DIR` | `ClaudeConfigPaths.swift:6` |
| Account config | `<root>/.config.json`, else `~/.claude.json` | `ClaudeConfigPaths.swift:19-34` |
| Env token override | `CLAUDE_CODE_OAUTH_TOKEN` (inference-only scope, from `claude setup-token`) | `ClaudeBar/Sources/Infrastructure/Claude/ClaudeCredentialLoader.swift:140-156` |

Keychain query CodexBar uses (it enumerates rather than assuming the account attribute, then picks
the most recently modified item):

```swift
// CodexBar/Sources/CodexBarCore/Providers/Claude/ClaudeOAuth/ClaudeOAuthCredentials.swift:2385-2391
var query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: self.claudeKeychainService,   // "Claude Code-credentials"
    kSecMatchLimit as String: kSecMatchLimitAll,
    kSecReturnAttributes as String: true,
    kSecReturnPersistentRef as String: true,
]
```

Candidates are sorted by `kSecAttrModificationDate ?? kSecAttrCreationDate`, newest first
(`ClaudeOAuthCredentials.swift:2418-2424`).

Shell fallback (used when the framework no-UI query is blocked). Note `-a <account>` is optional;
CodexBar passes it only when it already knows the account name:

```
/usr/bin/security find-generic-password -s "Claude Code-credentials" [-a <account>] -w
```
`.../ClaudeOAuth/ClaudeOAuthCredentials+SecurityCLIReader.swift:287-295`.
ClaudeBar uses the same shell call with no `-a`: `ClaudeBar/Sources/Infrastructure/Claude/ClaudeCredentialLoader.swift:272-275`.

### 1b. Credential JSON shape

Both the Keychain blob and `.credentials.json` hold the same JSON:

```json
{
  "claudeAiOauth": {
    "accessToken": "sk-ant-oat01-...",
    "refreshToken": "sk-ant-ort01-...",
    "expiresAt": 1767225600000,
    "scopes": ["user:profile", "user:inference", "user:sessions:claude_code"],
    "subscriptionType": "max",
    "rateLimitTier": "default_claude_max_20x"
  }
}
```

Field names are camelCase, `expiresAt` is **epoch milliseconds**:

```swift
// CodexBar/.../Claude/ClaudeOAuth/ClaudeOAuthCredentialModels.swift:113-115
let expiresAt = oauth.expiresAt.map { millis in
    Date(timeIntervalSince1970: millis / 1000.0)
}
```
Keys decoded: `accessToken`, `refreshToken`, `expiresAt`, `scopes`, `rateLimitTier`, `subscriptionType`
(`ClaudeOAuthCredentialModels.swift:129-145`).

**Pitfall:** on Claude Code 2.1.x the Keychain item can contain only `mcpOAuth` and no `claudeAiOauth`.
CodexBar detects this and fails with a re-auth message instead of retrying
(`ClaudeOAuthCredentialModels.swift:90-100`, documented at `CodexBar/docs/claude.md:68`).

### 1c. Usage endpoint

```
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer <accessToken>
Accept: application/json
Content-Type: application/json
anthropic-beta: oauth-2025-04-20
User-Agent: claude-code/<version>        # e.g. claude-code/2.1.0
```

Verbatim:

```swift
// CodexBar/.../Claude/ClaudeOAuth/ClaudeOAuthUsageFetcher.swift:81-93
var request = URLRequest(url: url)
request.httpMethod = "GET"
request.timeoutInterval = 30
request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Accept")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
// OAuth usage endpoint currently requires the beta header.
request.setValue(Self.betaHeader, forHTTPHeaderField: "anthropic-beta")
request.setValue(Self.claudeCodeUserAgent(...), forHTTPHeaderField: "User-Agent")
```

Constants at `ClaudeOAuthUsageFetcher.swift:61-65`: base `https://api.anthropic.com`,
usage path `/api/oauth/usage`, profile path `/api/oauth/profile`, beta `oauth-2025-04-20`,
fallback UA version `2.1.0`. The UA is `"claude-code/\(version)"` (`:200-203`); version is sniffed
from the installed CLI via `ProviderVersionDetector.claudeVersion`.

ClaudeBar sends `User-Agent: ClaudeBar` to the same endpoint and it works
(`ClaudeBar/Sources/Infrastructure/Claude/ClaudeAPIUsageProbe.swift:371-372`), so the UA is not
strictly gated — but `anthropic-beta` is required.

**Scope requirement:** the token needs `user:profile`. A `claude setup-token` token carrying only
`user:inference` cannot call usage (`CodexBar/docs/claude.md:69`).

Profile endpoint (identity only, no beta header):

```
GET https://api.anthropic.com/api/oauth/profile
Authorization: Bearer <accessToken>
```
→ `{ "account": { "email_address": ... }, "organization": { "uuid": ... } }`; the decoder accepts
`emailAddress` / `email_address` / `email` (`ClaudeOAuthUsageFetcher.swift:129-158, 215-234`).

### 1d. Usage response shape

```json
{
  "five_hour":            { "utilization": 42.5, "resets_at": "2026-09-03T18:00:00Z" },
  "seven_day":            { "utilization": 18.0, "resets_at": "2026-09-08T00:00:00Z" },
  "seven_day_opus":       { "utilization": 5.0,  "resets_at": "..." },
  "seven_day_sonnet":     { "utilization": 9.0,  "resets_at": "..." },
  "seven_day_oauth_apps": { "utilization": 0.0,  "resets_at": "..." },
  "seven_day_routines":   { "utilization": 3.0,  "resets_at": "..." },
  "limits": [
    { "kind": "weekly_scoped", "group": "weekly", "percent": 12.0,
      "resets_at": "...", "is_active": false,
      "scope": { "model": { "id": "claude-fable-5-1", "display_name": "Fable" } } }
  ],
  "extra_usage": {
    "is_enabled": true, "monthly_limit": 5000, "used_credits": 1234,
    "utilization": 24.7, "currency": "USD"
  }
}
```

Decoder: `ClaudeOAuthUsageFetcher.swift:268-414`.

- Window object is `{ utilization: Double?, resets_at: String? }` — `utilization` is already a
  **percent used** (0-100), `resets_at` is **ISO-8601** (`:355-363`).
- `limits[]` entries: `kind`, `group`, `percent`, `resets_at`, `is_active`,
  `scope.model.id`, `scope.model.display_name` (`:368-398`).
- `extra_usage`: `is_enabled`, `monthly_limit`, `used_credits`, `utilization`, `currency` (`:400-414`).
  **Amounts are in cents** and must be divided by 100
  (`CodexBar/.../Claude/ClaudeUsageFetcher.swift:1136-1146`).
- Routines key is looked up under several aliases: `seven_day_routines`, `seven_day_claude_routines`,
  `claude_routines`, `routines`, `routine`, `seven_day_cowork`, `cowork` (`:290-298`).

ISO parsing tries fractional seconds first, then plain internet date-time
(`ClaudeOAuthUsageFetcher.swift:165-174`).

### 1e. Mapping to "session % / weekly % / reset time"

```swift
// CodexBar/.../Claude/ClaudeUsageFetcher.swift:1031-1069
let primary = makeWindow(usage.fiveHour, windowMinutes: 5 * 60)
    ?? makeWindow(usage.sevenDay,          windowMinutes: 7 * 24 * 60)
    ?? makeWindow(usage.sevenDayOAuthApps, windowMinutes: 7 * 24 * 60)
    ?? makeWindow(usage.sevenDaySonnet,    windowMinutes: 7 * 24 * 60)
    ?? makeWindow(usage.sevenDayOpus,      windowMinutes: 7 * 24 * 60)
...
let weekly        = makeWindow(usage.sevenDay, windowMinutes: 7 * 24 * 60)
let modelSpecific = makeWindow(usage.sevenDaySonnet ?? usage.sevenDayOpus, windowMinutes: 7*24*60)
```

`makeWindow` sets `usedPercent = window.utilization` directly and `resetsAt = parseISO8601(resets_at)`
(`ClaudeUsageFetcher.swift:1016-1026`). So: session = `five_hour.utilization`,
weekly = `seven_day.utilization`, reset = the matching `resets_at`. If there is no window at all but
`extra_usage.is_enabled`, a synthetic spend-limit window is used instead (`:1042-1064`, `:1150-1165`).

### 1f. Token refresh

```
POST https://platform.claude.com/v1/oauth/token
Content-Type: application/x-www-form-urlencoded
Accept: application/json

grant_type=refresh_token&refresh_token=<rt>&client_id=9d1c250a-e61b-44d9-88ed-5944d1962f5e
```

Verbatim:

```swift
// CodexBar/.../Claude/ClaudeOAuth/ClaudeOAuthCredentials.swift:1443-1456
request.httpMethod = "POST"
request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
request.setValue("application/json", forHTTPHeaderField: "Accept")
var components = URLComponents()
components.queryItems = [
    URLQueryItem(name: "grant_type",    value: "refresh_token"),
    URLQueryItem(name: "refresh_token", value: refreshToken),
    URLQueryItem(name: "client_id",     value: ClaudeOAuthCredentialsStore.oauthClientID),
]
request.httpBody = (components.percentEncodedQuery ?? "").data(using: .utf8)
```

- Endpoint constant: `ClaudeOAuthCredentials.swift:28`.
- Client ID `9d1c250a-e61b-44d9-88ed-5944d1962f5e`, overridable via `CODEXBAR_CLAUDE_OAUTH_CLIENT_ID`
  (`ClaudeOAuthCredentials.swift:26-27`). ClaudeBar hardcodes the same ID
  (`ClaudeBar/.../ClaudeAPIUsageProbe.swift:154`).
- Response: `{ "access_token", "refresh_token"?, "expires_in" }`; new expiry is
  `now + expires_in` seconds (`ClaudeOAuthCredentials.swift:1493-1502`).
- ClaudeBar posts **JSON** instead of form-encoded and adds a `scope` field — also accepted:
  ```swift
  // ClaudeBar/.../ClaudeAPIUsageProbe.swift:294-300
  let body: [String: String] = [
      "grant_type": "refresh_token",
      "refresh_token": refreshToken,
      "client_id": Self.clientID,
      "scope": "user:profile user:inference user:sessions:claude_code"
  ]
  request.httpBody = try JSONSerialization.data(withJSONObject: body)
  ```

**Expiry detection:** `isExpired` is `Date() >= expiresAt`, and a nil `expiresAt` counts as expired
(`ClaudeOAuthCredentialModels.swift:37-40`). ClaudeBar refreshes 5 minutes early
(`ClaudeCredentialLoader.swift:161-168`).

**Ownership caveat:** Claude Code itself rotates the Keychain item. CodexBar distinguishes
CLI-owned vs self-owned credentials and delegates refresh back to the CLI for CLI-owned ones rather
than racing the rewrite (`ClaudeOAuthCredentials.swift:1550-1560`, `:3008`).

### 1g. Error handling / rate limits

`ClaudeOAuthUsageFetcher.swift:98-119`:

| Status | Handling |
|---|---|
| 200 | decode, clear rate-limit gate |
| 401 | `.unauthorized` → "run `claude` to re-authenticate" |
| 429 | parse `Retry-After`, arm a local block gate |
| 403 / other | `.serverError(code, body)` |

`Retry-After` parsing accepts either integer seconds or the HTTP-date format
`EEE',' dd MMM yyyy HH':'mm':'ss zzz` (`:176-191`).

**Pitfall (important):** the usage endpoint has been observed returning `Retry-After: 0` while still
429ing. ClaudeBar explicitly rejects 0 and falls back to 5 minutes, and caches snapshots for 15
minutes because a single call after a quiet period can trigger a 1-hour throttle
(`ClaudeBar/.../ClaudeAPIUsageProbe.swift:139-146`, `:565-571`; references anthropics/claude-code#30930).

### 1h. Local cost/spend from `~/.claude/projects` JSONL

CodexBar scans these roots (`CodexBar/Sources/CodexBarCore/Vendored/CostUsage/CostUsageScanner+Claude.swift:26-65`):

- `$CLAUDE_CONFIG_DIR/projects/` when set, else
- `~/.config/claude/projects/`
- `~/.claude/projects/`
- Claude Desktop roots via `ClaudeDesktopProjectsLocator`

Per JSONL line, it fast-rejects unless the raw bytes contain `"type":"assistant"` and `"usage"`, then
reads (`CostUsageScanner+Claude.swift:146-220`):

| JSON path | Meaning |
|---|---|
| `type` == `"assistant"` | row filter |
| `timestamp` | ISO-8601, gives the day bucket |
| `message.model` | model id for pricing |
| `message.usage.input_tokens` | input |
| `message.usage.cache_creation_input_tokens` | cache write |
| `message.usage.cache_creation.ephemeral_1h_input_tokens` | 1h-cache subtotal (`:250-251`) |
| `message.usage.cache_read_input_tokens` | cache read |
| `message.usage.output_tokens` | output |
| `message.id` + `requestId` | dedupe key for streaming chunks — later chunk overwrites |
| `sessionId` / `session_id` / `metadata.sessionId` | session grouping |
| `isSidechain` | subagent flag |

Cost is computed locally from a pricing table (`CostUsagePricing.ClaudeResolver.costUSD`,
`CostUsageScanner+Claude.swift:180-188`); the JSONL is not required to carry a cost field.

### 1i. Claude web (cookie) path — for reference only

`CodexBar/docs/claude.md:118-127`: cookie `sessionKey` (`sk-ant-...`) on domain `claude.ai`, then
`GET https://claude.ai/api/organizations`, `.../organizations/{orgId}/usage`,
`.../overage_spend_limit`, `.../prepaid/credits`, `.../api/account`. Implementation:
`CodexBar/Sources/CodexBarCore/Providers/Claude/ClaudeWeb/ClaudeWebAPIFetcher.swift`.

---

## 2. OpenAI Codex

### 2a. Credentials on disk

| What | Value | Cite |
|---|---|---|
| File | `~/.codex/auth.json`, or `$CODEX_HOME/auth.json` | `CodexBar/.../Codex/CodexOAuth/CodexOAuthCredentials.swift:100-112` |
| Legacy fallback | `~/.config/codex/auth.json` | `CodexOAuthCredentials.swift:392` |
| OpenCode fallback | `~/.local/share/opencode/auth.json` | `CodexOAuthCredentials.swift:427-446`, `CodexBar/docs/codex.md:73` |
| Config | `~/.codex/config.toml` (key `chatgpt_base_url`) | `CodexOAuthUsageFetcher.swift:687-694` |

No Keychain for Codex. `auth.json` shape:

```json
{
  "tokens": {
    "access_token": "eyJ...",
    "refresh_token": "...",
    "id_token": "eyJ...",
    "account_id": "org-..."
  },
  "last_refresh": "2026-09-03T10:00:00Z",
  "OPENAI_API_KEY": null
}
```

Parsing accepts both snake_case and camelCase for every token field
(`CodexOAuthCredentials.swift:271-299`). If `OPENAI_API_KEY` is present and non-empty it is treated as
an API-key credential that never refreshes (`:305-318`, `needsRefresh` returns false at `:50-52`).

### 2b. Account id from the JWT

When `tokens.account_id` is missing, it is recovered from the JWT payload of `id_token` (then
`access_token`), trying three claim paths in order:

```swift
// CodexBar/.../Codex/CodexOAuth/CodexOAuthCredentials.swift:491-516
if let accountID = nonEmpty(payload["chatgpt_account_id"] as? String) { return accountID }
if let auth = payload["https://api.openai.com/auth"] as? [String: Any],
   let accountID = nonEmpty(auth["chatgpt_account_id"] as? String) { return accountID }
if let organizations = payload["organizations"] as? [[String: Any]],
   let accountID = organizations.compactMap({ nonEmpty($0["id"] as? String) }).first { return accountID }
```

Base64url decode: `-`→`+`, `_`→`/`, pad to a multiple of 4 (`:495-499`).

### 2c. Expiry detection

`exp` is read out of the access token's JWT payload, with a raw-token scan that preserves integer
spelling (`CodexOAuthCredentials.swift:519-570`). `needsRefresh` is true within 5 minutes of `exp`
for native creds (60s for external sources); with no `exp`, it falls back to
`last_refresh` older than 8 days (`CodexOAuthCredentials.swift:49-61`).

### 2d. Usage endpoint

```
GET https://chatgpt.com/backend-api/wham/usage
Authorization: Bearer <access_token>
User-Agent: CodexBar
Accept: application/json
ChatGPT-Account-Id: <account_id>        # only when known
```

Verbatim:

```swift
// CodexBar/.../Codex/CodexOAuth/CodexOAuthUsageFetcher.swift:416-427
var request = URLRequest(url: Self.resolveUsageURL(env: env),
                         cachePolicy: .reloadIgnoringLocalCacheData,
                         timeoutInterval: 30)
request.httpMethod = "GET"
request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
request.setValue("CodexBar", forHTTPHeaderField: "User-Agent")
request.setValue("application/json", forHTTPHeaderField: "Accept")
if let accountId, !accountId.isEmpty {
    request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
}
```

Path constants (`CodexOAuthUsageFetcher.swift:386-390`):

- default base `https://chatgpt.com/backend-api/`
- `/wham/usage` when the base contains `/backend-api`, else `/api/codex/usage`
- `/wham/rate-limit-reset-credits`
- `/accounts/{accountId}/spend-controls/current-user/monthly-usage`

Base URL override: `chatgpt_base_url` in `~/.codex/config.toml`; a bare `https://chatgpt.com` or
`https://chat.openai.com` gets `/backend-api` appended automatically
(`CodexOAuthUsageFetcher.swift:652-666, 687-694`).

Two secondary calls use extra headers:

```swift
// CodexOAuthUsageFetcher.swift:538-546  (rate-limit reset credits)
request.setValue("codex-1",       forHTTPHeaderField: "OpenAI-Beta")
request.setValue("Codex Desktop", forHTTPHeaderField: "originator")
request.setValue(accountId,       forHTTPHeaderField: "ChatGPT-Account-ID")  // note capital ID here
```

Spend-controls monthly usage uses `ChatGPT-Account-Id` and requires a `/backend-api` base
(`:485-495`, `:620-637`).

### 2e. Usage response shape

```json
{
  "account_id": "org-...",
  "plan_type": "pro",
  "rate_limit": {
    "primary_window":   { "used_percent": 37, "reset_at": 1767225600, "limit_window_seconds": 18000 },
    "secondary_window": { "used_percent": 12, "reset_at": 1767830400, "limit_window_seconds": 604800 },
    "individual_limit": { "limit": 100.0, "used": 22.5, "remaining_percent": 77.5, "reset_at": 1767830400 }
  },
  "credits": { "has_credits": true, "unlimited": false, "balance": 12.34 },
  "additional_rate_limits": [
    { "limit_name": "GPT-5.3-Codex-Spark", "metered_feature": "...",
      "rate_limit": { "primary_window": {...}, "secondary_window": {...} } }
  ],
  "individual_limit": {...},
  "spend_control": { "individual_limit": {...} }
}
```

Decoder: `CodexOAuthUsageFetcher.swift:6-101` (root), `:157-201` (`rate_limit`),
`:203-214` (window), `:218-263` (`additional_rate_limits`), `:278-336` (spend-control limit),
`:338-364` (`credits`).

Window object — note these differ from Claude:

```swift
// CodexOAuthUsageFetcher.swift:203-214
public struct WindowSnapshot: Decodable, Sendable {
    public let usedPercent: Int          // "used_percent"       — Int, percent USED
    public let resetAt: Int              // "reset_at"           — UNIX EPOCH SECONDS
    public let limitWindowSeconds: Int   // "limit_window_seconds"
}
```

`plan_type` known values: `guest, free, go, plus, pro, free_workspace, team, business, education,
quorum, k12, enterprise, edu`, anything else → `.unknown(raw)` (`:101-155`).

Credit-limit precedence is root `individual_limit` → `rate_limit.individual_limit` →
`spend_control.individual_limit` (`:71-74`). `SpendControlLimitSnapshot` accepts `remaining_percent`
or `remainingPercent`, and `resets_at` / `resetsAt` / `reset_at` (`:278-303`), with flexible
Double/Int/String coercion (`:305-334`).

### 2f. Mapping to session / weekly

```swift
// CodexBar/Sources/CodexBarCore/UsageFetcher.swift:1283-1291
private static func makeWindow(from response: CodexUsageResponse.WindowSnapshot?) -> RateWindow? {
    guard let response else { return nil }
    let resetsAtDate = Date(timeIntervalSince1970: TimeInterval(response.resetAt))
    return RateWindow(
        usedPercent: Double(response.usedPercent),
        windowMinutes: response.limitWindowSeconds / 60,
        resetsAt: resetsAtDate,
        resetDescription: UsageFormatter.resetDescription(from: resetsAtDate))
}
```

`rate_limit.primary_window` → session lane, `secondary_window` → weekly lane, but the two are
**re-ordered by window length rather than trusted by name**: 300 minutes = session,
10080 minutes = weekly, and a primary that is actually weekly gets swapped into the weekly slot
(`CodexBar/.../Codex/CodexRateWindowNormalizer.swift:9-53`). Do the same; it is cheap insurance.

`additional_rate_limits[]` become named extra windows, e.g. Codex Spark
(`CodexBar/.../Codex/CodexAdditionalRateLimitMapper.swift`, described at `CodexBar/docs/codex.md:55-58`).

### 2g. Token refresh

```
POST https://auth.openai.com/oauth/token
Content-Type: application/json

{"client_id":"app_EMoamEEZ73f0CkXaXp7hrann",
 "grant_type":"refresh_token",
 "refresh_token":"<rt>",
 "scope":"openid profile email"}
```

Verbatim:

```swift
// CodexBar/.../Codex/CodexOAuth/CodexTokenRefresher.swift:45-58
var request = URLRequest(url: Self.refreshEndpoint, cachePolicy: .reloadIgnoringLocalCacheData,
                         timeoutInterval: 30)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
let body: [String: String] = [
    "client_id":     Self.clientID,        // "app_EMoamEEZ73f0CkXaXp7hrann"
    "grant_type":    "refresh_token",
    "refresh_token": credentials.refreshToken,
    "scope":         "openid profile email",
]
request.httpBody = try JSONSerialization.data(withJSONObject: body)
```

Endpoint and client id at `CodexTokenRefresher.swift:7-8`. Response fields consumed:
`access_token`, `refresh_token`, `id_token` (`:71-73`). Error codes mapped from
`error.code` / `error` / `code`: `refresh_token_expired` → expired, `refresh_token_reused` → reused,
`invalid_grant` / `refresh_token_invalidated` → revoked; bare 401 → expired (`:90-116`).

**Write-back caveat:** CodexBar never writes refreshed tokens back into `auth.json`; the CLI owns that
file, so stale native credentials are handed to the CLI for recovery instead
(`CodexBar/docs/codex.md:31-34`; `canPersistRefresh` at `CodexOAuthCredentials.swift:16-18`).

### 2h. Errors

`CodexOAuthUsageFetcher.swift:424-442`: 2xx decode; **401 and 403 both** → `.unauthorized`
("run `codex login`"); anything else → `.serverError(code, body)`. Cancellation is re-thrown as
`CancellationError`. No 429-specific handling.

---

## 3. Google Gemini CLI

### 3a. Credentials on disk

| What | Value | Cite |
|---|---|---|
| Credentials file | `~/.gemini/oauth_creds.json` | `CodexBar/.../Gemini/GeminiStatusProbe.swift:192` |
| Settings file | `~/.gemini/settings.json` | `GeminiStatusProbe.swift:193` |
| Newer CLI: Keychain service | `gemini-cli-oauth`, account `main-account` | `gemini-cli/packages/core/src/code_assist/oauth-credential-storage.ts:16-17` |
| File constants in CLI | `.gemini` + `oauth_creds.json` | `gemini-cli/packages/core/src/utils/paths.ts:13`, `packages/core/src/config/storage.ts:22,207` |

**Important:** current gemini-cli stores OAuth in the macOS Keychain under service `gemini-cli-oauth`,
account `main-account`, and only falls back to the JSON file for migration
(`oauth-credential-storage.ts:19-58`). CodexBar still reads only the file. A new app should try the
file first and the Keychain second.

`oauth_creds.json` fields (`GeminiStatusProbe.swift:896-921`):

```json
{
  "access_token": "ya29...",
  "refresh_token": "1//0...",
  "id_token": "eyJ...",
  "expiry_date": 1767225600000
}
```
`expiry_date` is **epoch milliseconds** (`:914-917`).

Auth type gate — read `security.auth.selectedType` from `settings.json`
(`GeminiStatusProbe.swift:222-238`): `oauth-personal` or unknown → proceed;
`api-key` / `gemini-api-key` and `vertex-ai` → hard error (`:241-250`).

Email and hosted domain come from the `id_token` JWT claims `email` and `hd`
(`GeminiStatusProbe.swift:931-950`).

### 3b. Required pre-call: loadCodeAssist (project id + tier)

```
POST https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist
Authorization: Bearer <access_token>
Content-Type: application/json

{"metadata":{"ideType":"GEMINI_CLI","pluginType":"GEMINI"}}
```
`GeminiStatusProbe.swift:451-465`.

Response fields consumed (`:1313-1390`):

- `cloudaicompanionProject` — either a string, or an object with `id` / `projectId`
- `currentTier.id` — one of `free-tier`, `legacy-tier`, `standard-tier` (`:166-171`)
- `paidTier.name` — authoritative plan label when present (`:1381-1389`)
- `ineligibleTiers[]` with `UNSUPPORTED_CLIENT` — consumer-shutdown signal

If `loadCodeAssist` returns no project, fall back to project discovery:

```
GET https://cloudresourcemanager.googleapis.com/v1/projects
Authorization: Bearer <access_token>
```
Pick the first project whose `projectId` starts with `gen-lang-client`, or that carries a
`labels["generative-language"]` key (`GeminiStatusProbe.swift:392-436`).

### 3c. Quota endpoint

```
POST https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota
Authorization: Bearer <access_token>
Content-Type: application/json

{"project": "<projectId>"}      # or {} when the project id is unknown
```

Verbatim:

```swift
// CodexBar/.../Gemini/GeminiStatusProbe.swift:338-352
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
if let projectId {
    request.httpBody = Data("{\"project\": \"\(projectId)\"}".utf8)
} else {
    request.httpBody = Data("{}".utf8)
}
```

Endpoint constants at `GeminiStatusProbe.swift:189-194`. No custom User-Agent is sent.

### 3d. Quota response shape

```json
{
  "buckets": [
    { "modelId": "gemini-2.5-pro", "remainingFraction": 0.83,
      "resetTime": "2026-09-04T00:00:00Z", "tokenType": "INPUT" }
  ]
}
```

Decoder `GeminiStatusProbe.swift:961-970`. Note the fields are **camelCase**, unlike Claude/Codex.

Mapping (`:972-1006`):

- Group buckets by `modelId`, keep the **lowest** `remainingFraction` per model.
- `percentLeft = remainingFraction * 100` — this is percent **remaining**, not used.
- `resetTime` parsed ISO-8601 (fractional seconds first, then plain) at `:1008-1017`.

Tier mapping to UI lanes (`GeminiStatusProbe.swift:43-98`), all with a 1440-minute (24h) window:

| Lane | Models | usedPercent |
|---|---|---|
| primary | modelId contains `pro` | `100 - percentLeft` |
| secondary | contains `flash` and not `flash-lite` | `100 - percentLeft` |
| tertiary | contains `flash-lite` | `100 - percentLeft` |

Gemini has no 5h/weekly split — treat "session" as the Pro daily bucket and "weekly" as absent,
or surface per-model rows.

Plan label (`:1275-1310`): `paidTier.name` wins; else `standard-tier` → paid, `free-tier` + `hd`
claim → Workspace, `free-tier` → Free, `legacy-tier` → Legacy.

### 3e. Token refresh

```
POST https://oauth2.googleapis.com/token
Content-Type: application/x-www-form-urlencoded

client_id=<id>&client_secret=<secret>&refresh_token=<rt>&grant_type=refresh_token
```

Verbatim:

```swift
// CodexBar/.../Gemini/GeminiStatusProbe.swift:840-851
let body = [
    "client_id=\(oauthCreds.clientID)",
    "client_secret=\(oauthCreds.clientSecret)",
    "refresh_token=\(refreshToken)",
    "grant_type=refresh_token",
].joined(separator: "&")
request.httpBody = body.data(using: .utf8)
```

Endpoint at `GeminiStatusProbe.swift:194`. Refresh is triggered when `access_token` is missing or
`expiry_date < now` (`:293-296`). After success, `access_token`, `id_token`, and a recomputed
`expiry_date = (now + expires_in) * 1000` are written back to `oauth_creds.json`
(`:875-895`).

**Client id/secret sourcing.** CodexBar does not hardcode them; it scrapes the installed CLI. Order
(`GeminiStatusProbe.swift:1111-1131`):

1. env `GEMINI_OAUTH_CLIENT_ID` + `GEMINI_OAUTH_CLIENT_SECRET` (`GeminiOAuthConfig.swift:33-34`)
2. env `GEMINI_OAUTH2_JS_PATH` pointing at an `oauth2.js`
3. installed CLI: `dist/src/code_assist/oauth2.js` under the resolved package root, plus a
   `bundle/gemini.js` import-graph walk (`:660-726`)
4. known Homebrew/npm install prefixes (`:1180-1217`)

The regex used (`:786-788`):

```swift
let clientIdPattern = #"(?:const|let|var)?\s*OAUTH_CLIENT_ID\s*=\s*['"]([\w\-\.]+)['"]\s*;"#
let secretPattern   = #"(?:const|let|var)?\s*OAUTH_CLIENT_SECRET\s*=\s*['"]([\w\-]+)['"]\s*;"#
```

The literal values, from gemini-cli source (`packages/core/src/code_assist/oauth2.ts:76-85`):

```
OAUTH_CLIENT_ID     = 681255809395-oo8ft2oprdrnp9e3aqf6av3hmdib135j.apps.googleusercontent.com
OAUTH_CLIENT_SECRET = GOCSPX-…   (see gemini-cli oauth2.ts; installed-app secret, scraped at runtime)
```
The source comments note this is an installed-application client, so the "secret" is not treated as
secret. Scraping is still safer than hardcoding, since Google can rotate it.

### 3f. Errors and pitfalls

- Quota 401 → not logged in; any non-200 → `.apiError("HTTP <code>")` (`GeminiStatusProbe.swift:359-378`).
- **Consumer-tier shutdown (2026-06-18):** Google stopped serving Gemini CLI OAuth for individual,
  AI Pro and Ultra accounts; Standard/Enterprise still work. Detection is text-matching on
  `unsupported_client`, `IneligibleTierError`, "no longer supported"+"gemini code assist", or
  Antigravity migration copy, checked on quota, loadCodeAssist and refresh responses
  (`GeminiStatusProbe.swift:132-155`, `CodexBar/docs/gemini.md:88-95`). Also: `loadCodeAssist`
  answers the shutdown with **HTTP 200**, no `currentTier`, and the consumer tier under
  `ineligibleTiers` (`:1344-1350`).
- A quota **403** is only treated as the shutdown when `loadCodeAssist` flagged the client
  unsupported **and** the tier is not `standard` (`:365-374`).
- `URLSession` timeouts against `cloudcode-pa.googleapis.com` are retried through a `/usr/bin/curl`
  subprocess fallback (`GeminiStatusProbe+DataLoader.swift:16-33, 44-100`). Worth knowing if you see
  unexplained timeouts.

---

## 4. Official CLI OAuth login parameters

Only needed if you implement your own login instead of reusing CLI credentials.

### 4a. Claude Code (verified from installed CLI binary 2.1.259, `strings` dump)

Constants object in the binary:

```
CONSOLE_AUTHORIZE_URL   https://platform.claude.com/oauth/authorize
CLAUDE_AI_AUTHORIZE_URL https://claude.com/cai/oauth/authorize      # used for --claudeai (subscription) login
TOKEN_URL               https://platform.claude.com/v1/oauth/token
MANUAL_REDIRECT_URL     https://platform.claude.com/oauth/code/callback
CLIENT_ID               9d1c250a-e61b-44d9-88ed-5944d1962f5e
```

Authorize URL builder (loopback variant, port is ephemeral — whatever the local listener bound):

```
<AUTHORIZE_URL>?code=true
  &client_id=9d1c250a-e61b-44d9-88ed-5944d1962f5e
  &response_type=code
  &redirect_uri=http://localhost:<port>/callback
  &scope=<space-joined>      # CLI full set: org:create_api_key user:profile user:inference user:sessions:claude_code user:mcp_servers user:file_upload
  &code_challenge=<S256>
  &code_challenge_method=S256
  &state=<random>
```

For a usage-only app request `user:profile user:inference` (usage endpoint needs `user:profile`).

Token exchange — JSON body, note the extra `state` field:

```
POST https://platform.claude.com/v1/oauth/token
Content-Type: application/json

{"grant_type":"authorization_code","code":"<code>","redirect_uri":"http://localhost:<port>/callback",
 "client_id":"9d1c250a-e61b-44d9-88ed-5944d1962f5e","code_verifier":"<verifier>","state":"<state>"}
```

Response: `access_token`, `refresh_token`, `expires_in` (seconds), `scope`. The CLI computes
`expiresAt = now + expires_in*1000` (ms). The callback query carries `code` and `state`; the CLI
also accepts a manually pasted `code#state` string when using MANUAL_REDIRECT_URL.

### 4b. Codex CLI (fully verified in openai/codex)

- client id `app_EMoamEEZ73f0CkXaXp7hrann`, env override `CODEX_APP_SERVER_LOGIN_CLIENT_ID`
  (`codex-cli/codex-rs/login/src/auth/manager.rs:1708-1714`)
- issuer `https://auth.openai.com`, callback port `1455`
  (`codex-cli/codex-rs/login/src/server.rs:59-60`)
- redirect uri `http://localhost:1455/auth/callback` (`server.rs:176`, route at `:346`)

Authorize URL (`server.rs:576-611`):

```
https://auth.openai.com/oauth/authorize
  ?response_type=code
  &client_id=app_EMoamEEZ73f0CkXaXp7hrann
  &redirect_uri=http://localhost:1455/auth/callback
  &scope=openid profile email offline_access api.connectors.read api.connectors.invoke
  &code_challenge=<S256>
  &code_challenge_method=S256
  &id_token_add_organizations=true
  &codex_cli_simplified_flow=true
  &state=<32 random bytes, base64url-nopad>
  &originator=<originator>
```

Token exchange (`server.rs:827-843`):

```
POST https://auth.openai.com/oauth/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code&code=<code>&redirect_uri=<redirect>&client_id=<id>&code_verifier=<verifier>
```

PKCE verifier/challenge generation: `codex-rs/login/src/pkce.rs:9-25` (SHA-256, base64url no pad).
A device-code flow also exists at `codex-rs/login/src/device_code_auth.rs`.

### 4c. Gemini CLI (fully verified in google-gemini/gemini-cli)

`packages/core/src/code_assist/oauth2.ts`:

- client id / secret: `:76-85` (values in section 3e)
- scopes `:88-92`:
  ```
  https://www.googleapis.com/auth/cloud-platform
  https://www.googleapis.com/auth/userinfo.email
  https://www.googleapis.com/auth/userinfo.profile
  ```
- loopback flow `:536-552`: ephemeral port, host from `OAUTH_CALLBACK_HOST` (default `127.0.0.1`),
  redirect `http://127.0.0.1:<port>/oauth2callback`, `access_type=offline`,
  `state` = 32 random hex bytes, verified on callback
- user-code flow `:441-455`: redirect `https://codeassist.google.com/authcode`, PKCE S256
- success/failure landing pages `:94-97`
- token exchange via `google-auth-library` `client.getToken({ code, redirect_uri })` (`:591-594`)

---

## 5. Summary table for a Swift menu-bar app

| | Claude Code | Codex | Gemini |
|---|---|---|---|
| Creds source | Keychain `Claude Code-credentials`, file `~/.claude/.credentials.json` | `~/.codex/auth.json` | `~/.gemini/oauth_creds.json`, newer Keychain `gemini-cli-oauth`/`main-account` |
| Expiry field | `claudeAiOauth.expiresAt` (epoch ms) | JWT `exp` in access token | `expiry_date` (epoch ms) |
| Usage call | `GET api.anthropic.com/api/oauth/usage` | `GET chatgpt.com/backend-api/wham/usage` | `POST cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota` |
| Extra required header | `anthropic-beta: oauth-2025-04-20` | `ChatGPT-Account-Id` | none, but `loadCodeAssist` first for the project id |
| Session % | `five_hour.utilization` (percent used) | `rate_limit.primary_window.used_percent` (Int, used) | `100 - remainingFraction*100` for the lowest Pro bucket |
| Weekly % | `seven_day.utilization` | `rate_limit.secondary_window.used_percent` | n/a (daily buckets only) |
| Reset | `resets_at`, ISO-8601 | `reset_at`, epoch seconds | `resetTime`, ISO-8601 |
| Refresh endpoint | `platform.claude.com/v1/oauth/token` (form) | `auth.openai.com/oauth/token` (JSON) | `oauth2.googleapis.com/token` (form) |
| Refresh client id | `9d1c250a-e61b-44d9-88ed-5944d1962f5e` | `app_EMoamEEZ73f0CkXaXp7hrann` | scraped from `oauth2.js` (see 3e) |
| Rate-limit hazard | 429 with `Retry-After: 0`; cache ≥15 min | none observed | consumer-tier 401/403/200-shutdown signals |
