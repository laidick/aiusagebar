# Antigravity quota reference (extracted from CodexBar + live probes, 2026-09-03)

Source tree: `/private/tmp/claude-501/-Users-dicklai-dev-source-aiusagebar/2562fe02-c61b-45cc-a11a-85d3cf34d595/scratchpad/research/CodexBar/`
All `file:line` citations below are relative to that root.

---

## 0. Executive summary (verified live today)

| Path | Verdict today | Evidence |
|---|---|---|
| `agy` CLI local HTTPS `RetrieveUserQuotaSummary` | **WORKS. Full per-window quota.** | live probe below |
| `loadCodeAssist` with `ideType: ANTIGRAVITY` | **200 OK, no `UNSUPPORTED_CLIENT`** | live probe below |
| `loadCodeAssist` with gemini-cli metadata | 200 but `ineligibleTiers[].reasonCode = UNSUPPORTED_CLIENT` | live probe below |
| `retrieveUserQuota` / `retrieveUserQuotaSummary` / `fetchAvailableModels` over OAuth with the **gemini-cli** client's token | **403 PERMISSION_DENIED** in every payload shape | live probe below |

**Recommendation for aiusagebar: implement the `agy` CLI local-server path first.** It needs no Google OAuth
client, no PKCE, no token refresh, and no CSRF token, and it returns exactly the two quota groups
(Gemini / Claude+GPT) with weekly and 5-hour windows, remaining fraction, and ISO reset times.
The OAuth path is a distant second: it requires minting a token under **Antigravity's own OAuth client**,
because the 403 is bound to the OAuth client identity, not the request body.

---

## 1. Local credential sources and what exists on this machine

### 1.1 CodexBar's own credential file (not an Antigravity file)

`Sources/CodexBarCore/Providers/Antigravity/AntigravityOAuthCredentialsStore.swift:474-483`

```swift
public static func defaultDirectoryURL(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
    home
        .appendingPathComponent(".codexbar", isDirectory: true)
        .appendingPathComponent("antigravity", isDirectory: true)
}

public static func defaultURL(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
    self.defaultDirectoryURL(home: home)
        .appendingPathComponent("oauth_creds.json")
}
```

Path: `~/.codexbar/antigravity/oauth_creds.json`, written `0o600`
(`AntigravityOAuthCredentialsStore.swift:499-505`). **Does not exist on this machine** (`~/.codexbar/` absent).
This file is created *by CodexBar's own login*; it is not something Antigravity writes.

JSON field names it accepts (snake and camel both decoded, snake always written) —
`AntigravityOAuthCredentialsStore.swift:112-128`:

```
access_token | accessToken
refresh_token | refreshToken
expiry_date | expiresAt        (milliseconds since epoch, Double or Int)
id_token | idToken
email
project_id | projectId
client_id | clientId
client_secret | clientSecret
```

An in-memory override exists for multi-account switching:
environment variable **`ANTIGRAVITY_OAUTH_CREDENTIALS_JSON`** holding the same JSON
(`AntigravityOAuthCredentialsStore.swift:419`, consumed at `AntigravityRemoteUsageFetcher.swift:538-544`).

### 1.2 The OAuth client id/secret are scraped from the installed app binary

`AntigravityOAuthCredentialsStore.swift:201-226` lists candidate artifacts inside the app bundle:

```swift
let relativePaths = [
    "Contents/Resources/app/extensions/antigravity/bin/language_server_macos_arm",
    "Contents/Resources/app/extensions/antigravity/bin/language_server_macos_x64",
    "Contents/Resources/app/extensions/antigravity/bin/language_server_macos",
    "Contents/Resources/app/out/main.js",
    "Contents/Resources/bin/language_server",
    "Contents/Resources/bin/language_server_macos",
    // Gemini.app is a single native binary with no Electron artifacts.
    "Contents/MacOS/Gemini",
]
```

Bundle ids accepted (`AntigravityOAuthCredentialsStore.swift:263-270`):
`com.google.antigravity`, `com.google.antigravity-ide`, `com.google.GeminiMacOS`.

Text scrape anchors on a marker then regexes (`:291-308`):

```swift
let marker = "vs/platform/cloudCode/common/oauthClient.js"
// clientID  pattern: [0-9]+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com
// secret    pattern: GOCSPX-[A-Za-z0-9_-]{28}
```

Binary scrape (`:310-383`) collects all matches; note the pairing heuristic comment at `:376`:
*"Antigravity 2's language_server binary stores the secret table before the client id table."*

**On this machine:** no `Antigravity.app`, no `Gemini.app`, no `Antigravity IDE.app` in `/Applications`
or `~/Applications`. So CodexBar's app-bundle discovery would fail here.

However **the `agy` CLI binary carries the same tables**. `/Users/dicklai/.local/bin/agy` (180 MB, 2026-09-02)
yields two client ids and two secrets:

```
1071006060591-tmhssin2h21lcre235vtolojh4g403ep.apps.googleusercontent.com
884354919052-36trc1jjb3tguiac32ov6cod268c5blh.apps.googleusercontent.com
GOCSPX-9YQW…   (redacted)
GOCSPX-K58F…   (redacted)
```

The same regexes in `AntigravityOAuthCredentialsStore.swift:298-302` extract these. aiusagebar can add
the `agy` binary to the candidate-artifact list to recover the Antigravity OAuth client without the desktop app.

### 1.3 Keychain

CodexBar reads **no** Keychain item for Antigravity. But `agy` clearly does. `security dump-keychain`
metadata (no secrets read) shows:

| service (`svce`) | account (`acct`) | note |
|---|---|---|
| `gemini` | `antigravity` | **modified 2026-09-03 06:45**, i.e. the live `agy` token store |
| `Antigravity Safe Storage` | `Antigravity Key` | Electron safeStorage master key |
| `Antigravity IDE Safe Storage` | `Antigravity IDE`, `Antigravity IDE Key` | IDE variant |
| `Gemini Safe Storage` | `Gemini Keys` | renamed-app variant |

`security find-generic-password -s gemini -a antigravity` returns metadata; reading the value (`-w`)
needs an interactive Keychain approval and was **not** performed. Item created 2026-05-20, modified today.

### 1.4 Antigravity data directories on this machine

`~/.gemini/antigravity/`, `~/.gemini/antigravity-cli/`, `~/.gemini/antigravity-ide/` all exist.
JSON/DB files present (**no credential file among them**):

```
~/.gemini/antigravity/     settings.json  mcp_config.json  package.json  gsd-file-manifest.json
                           antigravity_state.pbtxt  user_settings.pb  agyhub_summaries_proto.pb
                           installation_id  browserAllowlist.txt
~/.gemini/antigravity-cli/ settings.json  keybindings.json  jetski_state.pbtxt
                           conversation_summaries.db  history.jsonl  installation_id
                           cache/{onboarding,last_conversations,conversation_metadata}.json
                           conversations/*.db          <- token history, 7 databases
~/.gemini/antigravity-ide/ settings.json  mcp_config.json  package.json  gsd-file-manifest.json
```

CodexBar reads `conversations/*.db` only for **local token history / cost**, never for quota
(`docs/antigravity.md:264-339`). Roots recognized: `~/.gemini/antigravity-cli/conversations/*.db`,
`~/.gemini/antigravity/*.db`, `~/.gemini/antigravity/conversations/*.db`, with `GEMINI_CLI_HOME` overriding `~/.gemini`.

`~/.gemini/oauth_creds.json` exists and is the **Gemini CLI** credential (keys only):
`access_token, expiry_date, id_token, refresh_token, scope, token_type`. Its `expiry_date` was
2026-06-26, i.e. long stale, but its refresh token still works (see live probe).

---

## 2. Antigravity's OAuth login flow (`AntigravityLoginRunner.swift`)

Nothing is Antigravity-specific about the endpoints; it is a plain Google installed-app flow using
Antigravity's client credentials.

**Config** — `AntigravityOAuthCredentialsStore.swift:152-158`:

```swift
public static let authURL = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
public static let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
public static let userInfoURL = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!
public static let scopes = [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/userinfo.email",
]
```

**Authorize URL** — `AntigravityLoginRunner.swift:120-128`:

```swift
components.queryItems = [
    URLQueryItem(name: "client_id", value: oauthClient.clientID),
    URLQueryItem(name: "redirect_uri", value: redirectURL.absoluteString),
    URLQueryItem(name: "response_type", value: "code"),
    URLQueryItem(name: "scope", value: AntigravityOAuthConfig.scopes.joined(separator: " ")),
    URLQueryItem(name: "access_type", value: "offline"),
    URLQueryItem(name: "prompt", value: "select_account consent"),
    URLQueryItem(name: "state", value: state),
]
```

- **PKCE: none.** No `code_challenge` anywhere. It is a confidential-client-style flow with the
  secret embedded, exactly like gemini-cli.
- **State**: `UUID().uuidString` with dashes stripped (`:33`), checked both in the HTTP handler
  (`:370-372`) and again after (`:73-75`).
- **Redirect URI**: ephemeral loopback. A port is obtained by binding `127.0.0.1:0` and reading it back
  with `getsockname` (`:439-475`), then the URL is `http://127.0.0.1:<port>/callback` (`:273`). The path
  must be exactly `/callback` (`:367`).
- **Timeout**: 120 s default (`:25`).

**Token exchange** — `AntigravityLoginRunner.swift:140-150`, `POST https://oauth2.googleapis.com/token`,
`Content-Type: application/x-www-form-urlencoded`:

```
code, client_id, client_secret, redirect_uri, grant_type=authorization_code
```

Response decoded as `access_token`, `refresh_token`, `expires_in`, `id_token` (`:218-230`).

**Email**: `GET https://www.googleapis.com/oauth2/v2/userinfo` with `Authorization: Bearer <token>`
(`:168-184`). Failure is non-fatal, returns nil.

**Storage after login** — `:85-94`: build `AntigravityOAuthCredentials` with
`expiryDate = now + expires_in`, `projectID: nil`, plus the `clientID`/`clientSecret` used, then
`try AntigravityOAuthCredentialsStore().save(credentials)` → `~/.codexbar/antigravity/oauth_creds.json`.
Storing the client id and secret *inside* the credential matters: refresh prefers them over re-discovery
(`AntigravityRemoteUsageFetcher.swift:589-604`).

---

## 3. Quota endpoints

### 3.1 Local language-server endpoints (the good path)

Base: `https://127.0.0.1:<port>` — self-signed cert, TLS verification disabled for loopback only
(`docs/antigravity.md:345`).

Paths — `AntigravityStatusProbe.swift:846-851`:

```swift
private static let getUserStatusPath      = "/exa.language_server_pb.LanguageServerService/GetUserStatus"
private static let commandModelConfigPath = "/exa.language_server_pb.LanguageServerService/GetCommandModelConfigs"
private static let quotaSummaryPath       = "/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary"
private static let unleashPath            = "/exa.language_server_pb.LanguageServerService/GetUnleashData"
```

Request builder — `AntigravityStatusProbe.swift:1729-1741`:

```swift
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.httpBody = body                                    // JSONSerialization of payload.body, {} in practice
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.setValue(String(body.count), forHTTPHeaderField: "Content-Length")
request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
if endpoint.requiresCSRFToken {
    request.setValue(endpoint.csrfToken, forHTTPHeaderField: "X-Codeium-Csrf-Token")
}
```

**CSRF is required for the desktop app and the IDE language server, and NOT for the `agy` CLI.**
`AntigravityStatusProbe+LocalEndpoints.swift:2-12` builds CLI endpoints with `csrfToken: ""`.
`docs/antigravity.md:169`: *"The CLI HTTPS endpoint does not require `X-Codeium-Csrf-Token`."*
Confirmed live: my probe sent no CSRF header and got 200.

Process/port discovery (`docs/antigravity.md:89-129`): `ps -ax -o pid=,command=`, then kernel
process-socket enumeration on macOS (`lsof -nP -iTCP -sTCP:LISTEN -a -p <pid>` on Linux, `/proc` fallback).
`agy` is launched with **no arguments** in a PTY under its own process group
(`AntigravityCLISession.swift:856` `binary, arguments: []`, `:863` `openpty`, `:874-922` `posix_spawn` with
`posix_spawnattr_setpgroup(&attr, 0)`). CodexBar keeps it warm briefly then stops it on idle.

### 3.2 Live `RetrieveUserQuotaSummary` response, captured today

Launched `/Users/dicklai/.local/bin/agy` under a PTY, it bound port 61469, and:

```
POST https://127.0.0.1:61469/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary
Content-Type: application/json
Connect-Protocol-Version: 1
body: {}
-> 200
```

```json
{"response":{"groups":[
  {"displayName":"Gemini Models",
   "description":"Models within this group: Gemini Flash, Gemini Pro",
   "buckets":[
     {"bucketId":"gemini-weekly","displayName":"Weekly Limit Remaining",
      "description":"You have used some of your weekly limit, it will fully refresh in 5 days, 1 hour.",
      "window":"weekly","remainingFraction":0.81480396,"resetTime":"2026-09-08T08:47:29Z"},
     {"bucketId":"gemini-5h","displayName":"Five Hour Limit Remaining",
      "description":"You have used some of your 5-hour limit, it will fully refresh in 1 hour, 6 minutes.",
      "window":"5h","remainingFraction":0.6468816,"resetTime":"2026-09-03T08:34:13Z"}]},
  {"displayName":"Claude and GPT models",
   "description":"Models within this group: Claude Opus, Claude Sonnet, GPT-OSS",
   "buckets":[
     {"bucketId":"3p-weekly","displayName":"Weekly Limit Remaining",
      "window":"weekly","remainingFraction":1,"resetTime":"2026-09-10T07:27:56Z"},
     {"bucketId":"3p-5h","displayName":"Five Hour Limit Remaining",
      "window":"5h","remainingFraction":1,"resetTime":"2026-09-03T12:27:56Z"}]}],
 "description":"Within each group, models share a weekly limit and a 5-hour limit. …"}}
```

Note the payload carries an explicit **`window`** field (`"weekly"` / `"5h"`). CodexBar's parser does not
read it (`AntigravityQuotaSummaryParser.swift:137-149` has no `window` key) and instead infers window
length from bucket id / display name. **aiusagebar should just read `window` directly** and keep
bucket-id inference only as a fallback.

Parser mapping — `AntigravityQuotaSummaryParser.swift:43-88`:
- payload root accepted as `response`, or `summary`, or the top-level object itself (`:49`, `:104-107`).
- bucket requires a non-empty `bucketId` or it is dropped (`:79`).
- `remainingFraction` read either flat or nested as `remaining.remainingFraction`, including a
  protobuf-oneof spelling `{"case":"remainingFraction","value":…}` (`:146-172`).
- `resetTime` ISO-8601, with fractional seconds tried first then without
  (`AntigravityRemoteUsageFetcher.swift:516-524`); numeric epoch seconds as fallback per `docs/antigravity.md:234`.
- `disabled` defaults false.
- A group with zero valid buckets is dropped; zero groups is a parse failure (`:54-56`).

### 3.3 Live `GetUserStatus`, captured today (identity, plan, per-model quota)

```
POST https://127.0.0.1:61469/exa.language_server_pb.LanguageServerService/GetUserStatus  -> 200
```

Shape (identity fields redacted):

```json
{"userStatus":{
  "name":"<redacted>","email":"<redacted>","disableTelemetry":true,
  "planStatus":{"planInfo":{"teamsTier":"TEAMS_TIER_PRO","planName":"Pro",
      "monthlyPromptCredits":50000,"monthlyFlowCredits":150000, …},
    "availablePromptCredits":500,"availableFlowCredits":100},
  "cascadeModelConfigData":{"clientModelConfigs":[
    {"label":"Gemini 3.7 Flash (Low)","modelId":"gemini-3.7-flash-low",
     "modelOrAlias":{"model":"MODEL_PLACEHOLDER_M300"},
     "allowedTiers":["TEAMS_TIER_PRO", …],
     "quotaInfo":{"remainingFraction":0.6468816,"resetTime":"2026-09-03T08:34:13Z"},
     "tagTitle":"Fast","tagDescription":"Limited time","supportsImages":true,
     "isRecommended":true,"supportedMimeTypes":{…}},
    {"label":"Gemini 3.6 Flash (High)","modelId":"gemini-3.6-flash-high", …}, …]}}}
```

So **`accountEmail` and `planName` come only from `GetUserStatus`** (`docs/antigravity.md:236`), and every
model row's `quotaInfo.remainingFraction` mirrors the family bucket. Legacy field paths CodexBar reads
(`docs/antigravity.md:218-220`):

```
userStatus.cascadeModelConfigData.clientModelConfigs[].quotaInfo.remainingFraction
userStatus.cascadeModelConfigData.clientModelConfigs[].quotaInfo.resetTime
```

`GetCommandModelConfigs` returned **501 unimplemented** on `agy` today:
`{"code":"unimplemented","message":"unimplemented: unimplemented (error ID: …)"}`.
Treat fallback 2 as dead on the current CLI.

### 3.4 Remote OAuth endpoints

`AntigravityRemoteUsageFetcher.swift:36-40`:

```swift
private static let baseURL = "https://cloudcode-pa.googleapis.com"
private static let loadCodeAssistEndpoint      = "\(baseURL)/v1internal:loadCodeAssist"
private static let onboardUserEndpoint         = "\(baseURL)/v1internal:onboardUser"
private static let fetchAvailableModelsEndpoint = "\(baseURL)/v1internal:fetchAvailableModels"
private static let retrieveUserQuotaEndpoint   = "\(baseURL)/v1internal:retrieveUserQuota"
```

Headers — `:396-402`:

```swift
request.httpMethod = "POST"
request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.setValue("antigravity", forHTTPHeaderField: "User-Agent")   // userAgent = "antigravity", :35
```

**The metadata that matters** — `:164-170`:

```swift
let body = [
    "metadata": [
        "ideType": "ANTIGRAVITY",
        "platform": "PLATFORM_UNSPECIFIED",
        "pluginType": "GEMINI",
    ],
]
```

Status mapping — `:406-418`: 200 ok, 401 → `notLoggedIn`, 403 → `permissionDenied`, else `apiError`.

**Project id is a prerequisite** for the quota calls. `resolveProjectID` (`:326-382`):
stored `project_id` → `loadCodeAssist.cloudaicompanionProject` → else pick a tier
(`allowedTiers[].isDefault` → first `allowedTiers[].id` → `paidTier.id` → `currentTier.id`, `:496-514`)
and `POST :onboardUser` with `{"tierId": …, "metadata": {ideType ANTIGRAVITY, …}}`, then poll
`loadCodeAssist` five times at 2 s intervals. The resolved id is persisted back into the credential
(`:132-139`).

Quota body is just `{"project": "<id>"}`, or `{}` when unknown (`:186-190`, `:313-317`).
`metadata` is **not** accepted by these two endpoints (confirmed live: 400 `Unknown name "metadata"`).

Response shapes — `:742-765`:

```swift
private struct FetchAvailableModelsResponse: Decodable { let models: [String: AntigravityRemoteModel]? }
private struct AntigravityRemoteModel: Decodable { let displayName: String?; let label: String?; let quotaInfo: AntigravityRemoteQuotaInfo? }
private struct AntigravityRemoteQuotaInfo: Decodable { let remainingFraction: Double?; let resetTime: String? }
private struct RetrieveUserQuotaResponse: Decodable { let buckets: [RetrieveUserQuotaBucket]? }
private struct RetrieveUserQuotaBucket: Decodable { let modelId: String?; let remainingFraction: Double?; let resetTime: String? }
```

Note the remote `retrieveUserQuota` is **model-bucket** shaped (`modelId`), unlike the local
`RetrieveUserQuotaSummary` which is **group/bucket** shaped. `docs/antigravity.md:80-81` says
`retrieveUserQuotaSummary` exists over OAuth too but has been observed model-bucket shaped as well.

Plan/tier label — `:477-494`:

```swift
if let planType = response.planInfo?.planType { return planType }
switch (response.currentTier?.id, claims.hostedDomain) {
case ("standard-tier", _):  return "Paid"
case ("free-tier", .some):  return "Workspace"
case ("free-tier", .none):  return "Free"
case ("legacy-tier", _):    return "Legacy"
default: return response.currentTier?.name
}
```

`hostedDomain` is the `hd` claim of the id_token; `email` is the `email` claim, falling back to the
stored field (`:639-673`).

The all-100% guard — `:269-275` `shouldVerifyFullRemoteQuotas`: if every model reports
`remainingFraction >= 0.999`, CodexBar refuses to publish it as real usage and cross-checks with
`retrieveUserQuota`; if that returns nothing usable it returns `[]`. This is why the docs say the OAuth
path can only "prove model availability".

---

## 4. Token refresh

`AntigravityRemoteUsageFetcher.swift:553-587`. Triggered when `expiryDate - now <= 60 s`
(`refreshSafetyWindow = 60`, `:41`, `:153-156`).

```
POST https://oauth2.googleapis.com/token
Content-Type: application/x-www-form-urlencoded
client_id=<...>&client_secret=<...>&refresh_token=<...>&grant_type=refresh_token
```

Non-200 → `notLoggedIn`. On success it merges `access_token`, `expires_in` (as `now + expires_in` in
**milliseconds**), and `id_token` into the stored credential and persists
(`:606-624`, `:584-586`). Client id/secret come from the credential itself when present, otherwise from
app discovery (`:589-604`).

---

## 5. Live probe results (2026-09-03)

Scripts: `scratchpad/probe_ag.py`, `scratchpad/probe2.py`, `scratchpad/agy_probe.py`.
Credential used: refresh token from `~/.gemini/oauth_creds.json`, refreshed against the **gemini-cli**
client id `681255809395-oo8ft2oprdrnp9e3aqf6av3hmdib135j.apps.googleusercontent.com` scraped from
`/opt/homebrew/Cellar/gemini-cli/0.32.1/.../code_assist/oauth2.js`. All tokens redacted below.

**Refresh: 200.** Granted scopes: `cloud-platform openid userinfo.email userinfo.profile`.

**`loadCodeAssist` with `ideType: ANTIGRAVITY`, `pluginType: GEMINI` → 200**, and critically **no
`ineligibleTiers`**:

```json
{"currentTier":{"id":"free-tier","name":"Antigravity",
   "description":"Gemini-powered code suggestions and chat in multiple IDEs",
   "upgradeSubscriptionUri":"https://codeassist.google.com/upgrade",
   "upgradeSubscriptionType":"GDP_HELIUM", "privacyNotice":{"showNotice":true,"noticeText":"…"}},
 "allowedTiers":[{"id":"free-tier","name":"Antigravity", …}]}
```

`cloudaicompanionProject` resolved to **`aicode-consumers`**.

**Contrast, same token, gemini-cli-style metadata (`ideType: IDE_UNSPECIFIED`) → 200 but blocked:**

```json
{"allowedTiers":[{"id":"standard-tier","name":"Gemini Code Assist","isDefault":true,"usesGcpTos":true,
                  "userDefinedCloudaicompanionProject":true}],
 "ineligibleTiers":[{"reasonCode":"UNSUPPORTED_CLIENT",
   "reasonMessage":"This client is no longer supported for Gemini Code Assist for individuals. To continue using Gemini, please migrate to the Antigravity suite of products: https://antigravity.google",
   "tierId":"free-tier","tierName":"Gemini Code Assist for individuals"}]}
```

**Quota endpoints, every payload shape tried → 403:**

| endpoint | `{}` | `{"project":"aicode-consumers"}` | `{project, metadata}` |
|---|---|---|---|
| `retrieveUserQuota` | 403 PERMISSION_DENIED | 403 PERMISSION_DENIED | 400 `Unknown name "metadata"` |
| `retrieveUserQuotaSummary` | 403 PERMISSION_DENIED | 403 PERMISSION_DENIED | 400 |
| `fetchAvailableModels` | 403 PERMISSION_DENIED | 403 PERMISSION_DENIED | 400 |

```json
{"error":{"code":403,"message":"The caller does not have permission","status":"PERMISSION_DENIED"}}
```

Since `loadCodeAssist` succeeds with the same token and the same account, the 403 is **not** about the
account, the project, or the body. It tracks the **OAuth client**. A token minted under Antigravity's
own client id is required.

**`agy` CLI local probe → full success.** Spawned under a PTY, port 61469 discovered via `lsof`,
`RetrieveUserQuotaSummary` and `GetUserStatus` both 200 (payloads in §3.2 and §3.3),
`GetCommandModelConfigs` 501. The spawned process was terminated afterwards and verified gone.

---

## 6. Pitfalls

1. **Readiness is not port-binding.** `agy` binds its port before the quota service answers; CodexBar
   retries until an endpoint *parses*, not until a socket opens (`docs/antigravity.md:180-181`).
   The first refresh after a cold start waits on macOS keyring auth and can take several extra seconds
   (`docs/antigravity.md:36-38`). My own probe polled every 3 s and needed more than one round.
2. **Never kill a user's `agy`.** CodexBar records its own pid + executable identity and reaps only its
   own stale process (`docs/antigravity.md:184-186`). It first spends up to 2 s looking for an
   already-running same-user `agy` to reuse (`:170-174`).
3. **CSRF asymmetry.** App and IDE language servers require `--csrf_token`; a tokenless desktop match is
   skipped rather than used. The CLI exposes no such flag and needs none
   (`docs/antigravity.md:110-115`, `AntigravityStatusProbe.swift:1209-1267`).
4. **Do not attach the app-local strategy to an IDE or CLI process.** The IDE payload is poorer and
   would mask `agy`'s richer summary; a still-initializing `agy` accepts connections before it is ready
   (`docs/antigravity.md:91-96`).
5. **`RetrieveUserQuotaSummary` returns 404 from the IDE local server** — the IDE can only give session
   bars, never the weekly limit (`docs/antigravity.md:190-194`).
6. **All-100% payloads are suspect.** Treat a response where every model reports `>= 0.999` as
   availability data, not usage, and cross-check (`AntigravityRemoteUsageFetcher.swift:269-275`).
7. **Rows with `resetTime` but no `remainingFraction`** must be marked `usageKnown: false` and not
   rendered as exhausted quota (`docs/antigravity.md:246-248`).
8. **Every plan reports every family.** A Gemini-only user still gets a Claude/GPT pair pinned at
   100% remaining. Hide a family when every lane reports known zero usage, but keep families with
   unknown usage visible (`docs/antigravity.md:254-259`). My live capture shows exactly this:
   `3p-weekly` and `3p-5h` both at `remainingFraction: 1`.
9. **Loopback TLS is self-signed.** Disable verification only for `127.0.0.1`
   (`docs/antigravity.md:345`, `AntigravityStatusProbe+LocalEndpoints.swift:14-22`).
10. **Internal protocol, no stability guarantee** (`docs/antigravity.md:342`). Both the `exa.language_server_pb`
    service and `v1internal:` are unversioned internal surfaces.
11. **`metadata` is rejected by the quota endpoints** (live 400). It belongs only on `loadCodeAssist`
    and `onboardUser`.
12. **Expiry units.** The credential stores `expiry_date` in **milliseconds**; `expires_in` from Google is
    seconds. Mixing them silently disables refresh.
13. Do not scrape the desktop UI or the `agy` TUI. CodexBar explicitly does neither
    (`docs/antigravity.md:41`, `:157-159`); it drains and discards PTY output only to stop the CLI
    blocking on a full terminal buffer (`AntigravityCLISession.swift:116`).

---

## 7. Recommended implementation order for aiusagebar

1. **`agy` CLI local HTTPS.** Resolve the binary via `ANTIGRAVITY_CLI_PATH` → `PATH` →
   `~/.local/bin/agy`, `/opt/homebrew/bin/agy`, `/usr/local/bin/agy`. Reuse a running same-user `agy`
   if one answers within ~2 s; otherwise spawn it with no arguments under a PTY in its own process group.
   Discover listening ports, POST `{}` to `RetrieveUserQuotaSummary` with
   `Content-Type: application/json` and `Connect-Protocol-Version: 1`, no CSRF, TLS verification off for
   loopback. Retry until a payload parses. Then `GetUserStatus` for email and plan name.
   This is verified working on this machine today and needs no Google credentials at all.
2. **Antigravity app local probe** when `Antigravity.app` is running, same paths plus
   `X-Codeium-Csrf-Token` from the process's `--csrf_token` argument.
3. **OAuth**, only if you implement a real Antigravity-client login: scrape client id and secret from
   the `agy` binary or an installed app bundle using the two regexes in §1.2, run the loopback flow in
   §2, then `loadCodeAssist` with `ideType: ANTIGRAVITY` to get the project, then
   `fetchAvailableModels` / `retrieveUserQuota`. Reusing a gemini-cli token will not work: 403.
