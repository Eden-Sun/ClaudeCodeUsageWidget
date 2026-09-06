# Project Status: ACTIVE ✅

Previously blocked on "no usage API". That turned out to be the wrong endpoint,
not a missing feature — resolved 2026-08-12.

## How usage is read

```
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer <Claude Code OAuth access token>
anthropic-beta: oauth-2025-04-20
Content-Type: application/json
```

Auth comes from the tokens Claude Code already stores in the login Keychain:

- service: `Claude Code-credentials` for the default config directory
  (`~/.claude`). Claude Code keys its credentials by config directory, so any
  other `CLAUDE_CONFIG_DIR` gets `-<first 8 hex of sha256(absolute path)>`
  appended — e.g. `Claude Code-credentials-81129bfc`
- account: written by the CLI. Usually the local username, but not guaranteed,
  so it is never assumed — see the two-step read below
- payload: `{"claudeAiOauth":{"accessToken":"sk-ant-oat01-…","expiresAt":<ms epoch>,…}}`

`discoverAccounts()` enumerates every generic-password item whose service starts
with `Claude Code-credentials` and maps each suffix back to a directory by
hashing every `~/.claude*` directory it can find. A slot whose directory has
been deleted shows the raw hash. Only attributes are read here, never the
payload, so discovery cannot raise an access prompt.

`credentials(for:)` then reads one slot in **two steps**, on purpose:

1. an attributes-only query (`kSecMatchLimitAll`, `kSecReturnAttributes`) to
   enumerate the account attributes stored under that service;
2. a `kSecMatchLimitOne` + `kSecReturnData` read per account, until one yields a
   usable `claudeAiOauth.accessToken`.

The split is not incidental. Asking for `kSecReturnData` under
`kSecMatchLimitAll` makes the Keychain silently skip anything that would need
authorization instead of showing the "wants to use your confidential
information" prompt — which left the app with no token at all after a rebuild
changed its signature.

The blob is then held in memory, and re-read when any of three things says it is
no longer what's stored: the item's modification date changed, the access token
is within a minute of expiry, or a request came back 401. The modification date
is the one that catches an account switch — `claude login` replaces the identity
in a slot without moving the expiry, and the token it displaces usually stays
valid, so neither of the other two would fire. Comparing it costs nothing, since
reading attributes never prompts. The cache is
about the *prompt*, not speed: reading the payload is what raises "wants to use
your confidential information", and an uncached read on every 5-minute poll put
that dialog up every 5 minutes on any build whose signature isn't in the item's
ACL. A 401 drops the cached blob, so a token revoked or rotated out by a
`claude login` elsewhere is re-read rather than re-sent until its paper expiry.

Profiles are rediscovered every poll (attributes only), so a login or logout
shows up without a restart. There is no API key, no organization ID, and no
session cookie.

Signing identity comes from `Signing.xcconfig`, which defaults to ad-hoc so a
fresh clone builds anywhere, and optionally includes a gitignored
`Local.xcconfig` to override it per machine. Overriding it locally matters more
than it looks: an ad-hoc signature's designated requirement is the binary's
cdhash, so every rebuild looks like a brand-new app to the Keychain and "Always
Allow" never survives one. The include sits *after* the defaults in that file —
last assignment wins in an xcconfig, so an include above them gets overwritten
by the very lines it is meant to override.

## Grok usage

Read from the Grok CLI over ACP, never from grok.com.

```
grok agent stdio
  -> {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":1,…}}
  -> {"jsonrpc":"2.0","id":2,"method":"_x.ai/billing","params":{}}
  <- {"config":{"creditUsagePercent":14.0,
                "currentPeriod":{"type":"USAGE_PERIOD_TYPE_WEEKLY","start":…,"end":…}},
      "subscription_tier":"SuperGrok"}
```

Only the `initialize` handshake is required — no `session/new`, so nothing is
written to `~/.grok/sessions`, no model is called, and no quota is spent. About
a second end to end.

grok.com itself is unreachable from a native app and always will be. Cloudflare
binds `cf_clearance` to the IP, the User-Agent *and* the TLS/JA3 fingerprint,
and the fingerprint is taken from the ClientHello — before any header, cookie or
script. `URLSession` cannot produce a browser's fingerprint, so a copied cookie
dies on first reuse; a mismatched pair (URLSession TLS, Chrome User-Agent) is a
stronger bot signal than an honest one. Probed `/usage`, `/rest/usage`,
`/api/usage` and `/rest/rate-limits` with a full browser User-Agent: all 403,
all the interstitial. The wall is below HTTP, so no endpoint on that host is a
way round it.

The CLI's `/usage` command is a different thing — `_x.ai/session/usage`, which
returns one session's token counts (`inputTokens`, `modelCalls`, `numTurns`),
not the subscription quota.

Both methods are undocumented internals of xAI's CLI. Parsing requires only
`creditUsagePercent`, so a renamed period field costs the reset time rather than
the row.

### Response shape

```json
{
  "five_hour": { "utilization": 25.0, "resets_at": "2026-08-12T05:10:00.633192+00:00" },
  "seven_day": { "utilization": 41.0, "resets_at": "2026-08-14T06:00:00.633215+00:00" },
  "limits": [
    { "kind": "session",       "percent": 25, "severity": "normal", "is_active": false },
    { "kind": "weekly_all",    "percent": 41, "severity": "normal", "is_active": true  },
    { "kind": "weekly_scoped", "percent": 10, "scope": { "model": { "display_name": "Fable" } } }
  ],
  "extra_usage": { … },
  "spend": { "used": { "amount_minor": 0, "currency": "USD" }, "percent": 0 }
}
```

The 5-hour gauge and the "Weekly" bar are driven by the top-level `five_hour`
and `seven_day` windows. `limits[]` is the only place the **per-model** weekly
caps appear (`kind: "weekly_scoped"`, labelled from `scope.model.display_name`),
so those rows come from there. `severity` and `is_active` are parsed but not yet
used for anything. `extra_usage` and `spend` are ignored.

Every figure the UI shows is `100 - percent`, i.e. remaining headroom.

## Plan name and identity

Read from `GET https://api.anthropic.com/api/oauth/profile`:
`account.has_claude_max` plus the multiplier at the end of
`organization.rate_limit_tier` ("default_claude_max_5x" → "Max 5×"), else
`account.has_claude_pro` → "Pro", else `organization.organization_type` with the
`claude_` prefix stripped. `account.email` comes from the same response.

This is **not** read from the Keychain blob's `subscriptionType` field — that
one goes stale after a plan change and reported `pro` for a Max account.

Identity doesn't change between polls, so it is cached per profile rather than
re-fetched every 5 minutes. The cache entry is stamped with a SHA-256
fingerprint of the access token it was fetched with, so a profile re-logged-in
as a different account misses the cache instead of showing the old email until
the next relaunch.

## What the earlier investigation got wrong

| Recorded as blocking | Actual |
| --- | --- |
| Official usage endpoints all 404 | Wrong paths. It is `/api/oauth/usage`, not under `/v1/` |
| Needs a session cookie; 403 Forbidden | Cookies aren't involved. The 403 came from hitting `claude.ai`, which is behind Cloudflare — use `api.anthropic.com` |
| Needs an Organization ID | Not needed; the OAuth token identifies the account |

The Admin **Usage & Cost API** (`/v1/organizations/usage_report/messages`,
`/v1/organizations/cost_report`) is a separate, documented product for
org-level *API* billing. It has nothing to do with subscription limits and is
not used here.

## Caveats

- `/api/oauth/usage` and `/api/oauth/profile` are undocumented endpoints that
  Claude Code itself calls. They can change without notice, so parsing is
  deliberately lenient — a missing field degrades one row of the display rather
  than failing the fetch.
- Access tokens expire after hours (`expiresAt` in the blob, ms since epoch) and
  the CLI only renews one while it is running, so a profile you have not used
  since morning sits on a dead token. The app therefore runs the refresh grant
  itself:

  ```
  POST https://api.anthropic.com/v1/oauth/token
  Content-Type: application/json
  {"grant_type":"refresh_token","refresh_token":"sk-ant-ort01-…",
   "client_id":"9d1c250a-e61b-44d9-88ed-5944d1962f5e"}
  ```

  `client_id` is the one Claude Code itself authenticates as. The host is
  `api.anthropic.com`; `console.anthropic.com` answers too but rate-limits hard.

  The server **rotates** the refresh token, so the new blob must be written back
  to the same Keychain item (`SecItemUpdate` on the payload only, leaving the
  CLI's attributes and access control alone) or the CLI is left holding a
  retired token. The write is done before the new access token is used, and a
  failed write aborts the refresh — surfaced as its own error, "Session renewed
  but the new token could not be saved", rather than as a failed refresh.

  A refresh is also attempted once when a token that has not formally expired
  comes back 401 — a revoked session, or a clock disagreeing with the server.
  Concurrent refreshes of the same profile are collapsed into one in-flight
  request, since rotating the token twice invalidates the first result.
- Refresh tokens outlive access tokens by a long way (`refreshTokenExpiresAt`).
  Past that, or if the grant is refused, the profile really does need a
  re-login — and the column keeps showing its last successful reading, marked
  stale and annotated with the exact login command, rather than blanking.

---

**Last Updated**: 2026-09-04
