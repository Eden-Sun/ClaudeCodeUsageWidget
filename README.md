# Claude Code Usage Widget

A macOS menu bar app that shows how much of your Claude subscription you have
**left** — the 5-hour session window, the weekly cap, and the per-model weekly
caps the top-level numbers hide.

It reuses the login Claude Code already has. No API key, no organization ID, no
cookie, nothing to configure.

```
eddie | 5h:75% (rst 2h 41m) | 7d:59% (rst 4d 2h) | Fable:70%
```

## Requirements

- macOS 13 (Ventura) or later
- Claude Code installed and signed in (`claude login`), on a Pro or Max plan
- Xcode 15 or later, to build

## Install

```bash
git clone https://github.com/Eden-Sun/ClaudeCodeUsageWidget.git
cd ClaudeCodeUsageWidget
./scripts/make-dmg.sh          # -> dist/ClaudeCodeUsageWidget-<version>.dmg
```

Open the DMG, drag the app to Applications, launch it. Or open
`ClaudeCodeUsageWidget.xcodeproj` in Xcode and press ⌘R.

On first launch macOS asks whether the app may read the
`Claude Code-credentials` Keychain item. Click **Always Allow** — that item
holds the OAuth token the app authenticates with, and there is nothing else to
grant.

There is no Developer ID and no notarization here, so Gatekeeper blocks the
build on any Mac other than the one that produced it. Elsewhere: right-click the
app → Open, or `xattr -dr com.apple.quarantine /Applications/ClaudeCodeUsageWidget.app`.

## Code signing, and why you should care locally

A fresh clone builds ad-hoc signed, so it works on any Mac with no Apple
developer account. That default has one cost worth understanding.

An ad-hoc signature's designated requirement is the binary's cdhash. Change one
byte of code and the signature identifies a different program — so to the
Keychain, **every rebuild is a brand-new app that has never been granted
anything**. "Always Allow" is not ignored; it was granted to the previous build.
The result is a password prompt after every single rebuild, forever.

Signing with a certificate makes the requirement identity + certificate based,
which is stable across rebuilds, so the grant sticks. An Apple Development
certificate from a free Apple ID is enough — this is about a stable local
signature, not distribution.

Create `Local.xcconfig` next to `Signing.xcconfig` (it is gitignored):

```
WIDGET_SIGN_IDENTITY = <SHA-1 or name from `security find-identity -v -p codesigning`>
WIDGET_DEVELOPMENT_TEAM = <your 10-character team ID>
```

`scripts/make-dmg.sh` gets there by another route: it re-signs the built app
with whatever identity `security find-identity` reports, so a DMG build has a
stable signature without any file here. Set `SIGN_IDENTITY` to choose among
several; the script prints the one it used.

## Multiple profiles

Claude Code keys its credentials by config directory, and the app follows.
Every `CLAUDE_CONFIG_DIR` you have logged in gets its own Keychain slot, its own
column in the popover, and its own line in the menu bar.

Profiles are rediscovered on every poll, so a login or logout shows up without a
restart. The only setting is which profile the menu bar leads with — **Settings
→ Show account**, or right-click the menu bar item and pick one under **Menu bar
shows**. It is remembered across relaunches.

## How it works

**Auth.** Claude Code stores an OAuth token in the login Keychain under service
`Claude Code-credentials` (the default `~/.claude`), or
`Claude Code-credentials-<first 8 hex of sha256(config dir)>` for any other
`CLAUDE_CONFIG_DIR`. The app discovers profiles by reading Keychain *attributes*
only, which never raises an access prompt, and reads the secret payload only
when it actually needs a token.

**Credential cache.** A token blob is held in memory until it is within a minute
of expiring, then re-read from the Keychain. Reading the payload is what raises
the "wants to use your confidential information" dialog, and the app polls every
5 minutes — so an uncached read meant that dialog every 5 minutes on any build
whose signature isn't in the item's ACL. A 401 drops the cached blob, so a token
revoked or rotated out by a `claude login` elsewhere is re-read rather than
re-sent until its recorded expiry.

**Refresh.** The CLI only renews a token while it is running, so a profile left
idle sits on an expired token indefinitely. The app runs the refresh grant
itself and writes the rotated token back to the same Keychain item. If that
write fails, it says so and stops rather than using the token — the exchange has
already retired the one the CLI holds, and only `claude login` recovers from
there.

**Polling.** Every 5 minutes; opening the popover refreshes anything older than
30 seconds. Change `updateInterval` in `UsageMonitor.swift` to adjust.

**Degraded readings.** A profile that can't be polled keeps its last good
numbers on screen, marked stale and labelled with the command that fixes it,
instead of blanking. The usage windows move slowly enough that an hour-old
reading still tells you where you stand.

**Colour.** Tracks the 5-hour window's remaining percentage: green above 50%,
yellow 20–50%, red at or below 20%.

## API

```
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer <Claude Code OAuth access token>
anthropic-beta: oauth-2025-04-20
```

Returns `five_hour` / `seven_day` utilization plus a `limits` array carrying
per-model weekly caps. Plan name and email come from `GET /api/oauth/profile`.
An expired token is renewed with `POST /v1/oauth/token`
(`grant_type=refresh_token`).

These endpoints are undocumented — they are what Claude Code itself calls — and
may change without notice. Parsing is deliberately lenient, so a changed field
degrades one row rather than breaking the app. Full response shape in
[STATUS.md](STATUS.md).

## Troubleshooting

**macOS keeps asking for the Keychain password.** Almost always an ad-hoc build:
see [Code signing](#code-signing-and-why-you-should-care-locally) above. If the
dialog names `security` rather than `ClaudeCodeUsageWidget`, it isn't this app —
something else on your machine is shelling out to `security` to read the same
item, a statusline script being the usual culprit.

**"No Claude Code login found."** Run `claude login`, then hit Refresh. If you
clicked Deny on the Keychain prompt, grant it again in Keychain Access →
`Claude Code-credentials` → Access Control (a non-default profile is under
`Claude Code-credentials-<8 hex>`).

**"Session expired and could not be renewed" / 401.** The app renews expired
access tokens on its own, so this means the refresh token has lapsed too
(~2 weeks) or the grant was refused. Run the command the popover shows for that
profile.

**"Session renewed but the new token could not be saved."** The refresh
succeeded but the rotated token couldn't be written back, which would leave the
CLI holding a retired token — so the app refuses to use it. Check the app's
access to that Keychain item, then run `claude login`.

**Nothing in the menu bar.** `LSUIElement` must be `true` in
`ClaudeCodeUsageWidget/Info.plist`. The target sets `GENERATE_INFOPLIST_FILE = NO`
and points `INFOPLIST_FILE` at that file, so the plist wins — the
`INFOPLIST_KEY_LSUIElement` build setting is not consulted.

## Project layout

```
ClaudeCodeUsageWidget/
├── ClaudeCodeUsageApp.swift   # Lifecycle, status bar item, SwiftUI views
├── UsageMonitor.swift         # Endpoints, polling, parsing, degraded state
└── KeychainHelper.swift       # Profile discovery, token read/cache/refresh
Signing.xcconfig               # Code signing identity (Local.xcconfig overrides)
scripts/make-dmg.sh            # Release build -> signed .app -> .dmg
```

## Privacy

The app stores no credentials of its own. It reads the tokens Claude Code
already keeps in your login Keychain, and a token it renews goes straight back
to the same Keychain item. It talks to Anthropic's API and nothing else — no
analytics, no tracking, no other data leaves the machine.

## License

MIT — see [LICENSE](LICENSE).

---

Unofficial, and not affiliated with Anthropic.
