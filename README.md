# Claude Code Usage Widget

A macOS menu bar app that shows how much of your Claude subscription you have
**left** — the 5-hour session window, the weekly cap, and the per-model weekly
caps the top-level numbers hide. It reads a Grok subscription's weekly usage
too, when the Grok CLI is installed.

It reuses the logins the CLIs already have. No API key, no organization ID, no
cookie, nothing to configure.

```
● 84 59
● --  ● Grok 86
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
restart. They are ordered by when each was first logged in, so a new one lands
at the end and leaves the existing positions alone. (Alphabetical was the
obvious choice and the wrong one — it sorts `cc2` ahead of `ccompany` on the
third character, reshuffling profiles already on screen into an order matching
nothing the user knew.) Re-running `claude login` on an existing profile
rewrites its Keychain item in place and does not move it. The only setting is which profile the menu bar leads with — **Settings
→ Show account**, or right-click the menu bar item and pick one under **Menu bar
shows**. It is remembered across relaunches.

## Grok

If the [Grok CLI](https://grok.com) is installed and signed in, the menu bar
gains a `Grok` figure: the percentage left in the current billing period, with
its reset time in the tooltip. Nothing to configure — the CLI already holds the
session, and the app finds it in the usual install locations (`~/.local/bin`,
Homebrew). Settings → Grok takes an explicit path for an install elsewhere.

The figure comes from the CLI, not from grok.com. That is not a shortcut, it is
the only thing that works. grok.com sits behind Cloudflare, whose `cf_clearance`
cookie is bound to the IP, the User-Agent **and** the TLS/JA3 fingerprint of the
client that solved the challenge — the fingerprint is taken from the ClientHello,
before a single header or cookie is sent. A native `URLSession` has its own
fingerprint, so a cookie copied out of a browser is dead on first reuse, and a
request whose TLS says "URLSession" while its User-Agent claims to be Chrome
reads as more suspicious than one that never lied. No endpoint on that host is
reachable this way; the wall is below HTTP, so switching paths changes nothing.

The CLI, meanwhile, already holds a working OAuth session in `~/.grok/auth.json`
and speaks [ACP](https://agentclientprotocol.com) over stdio. The app spawns
`grok agent stdio`, sends the `initialize` handshake and the `_x.ai/billing`
extension method, reads the reply and exits:

```json
{ "config": { "creditUsagePercent": 14.0,
              "currentPeriod": { "type": "USAGE_PERIOD_TYPE_WEEKLY",
                                 "start": "…", "end": "…" } },
  "subscription_tier": "SuperGrok" }
```

No session is created, no model is called, and no quota is spent — the whole
exchange takes about a second. (The CLI's own `/usage` command is a different
thing: it reports one session's token counts via `_x.ai/session/usage`, not the
subscription's quota.)

Both of these are undocumented internals of someone else's CLI and may change
without notice. When they do, the row degrades to `--` with the reason in the
tooltip; nothing else is affected.

## How it works

**Auth.** Claude Code stores an OAuth token in the login Keychain under service
`Claude Code-credentials` (the default `~/.claude`), or
`Claude Code-credentials-<first 8 hex of sha256(config dir)>` for any other
`CLAUDE_CONFIG_DIR`. The app discovers profiles by reading Keychain *attributes*
only, which never raises an access prompt, and reads the secret payload only
when it actually needs a token.

**Credential cache.** A token blob is held in memory rather than re-read on
every poll. Reading the payload is what raises the "wants to use your
confidential information" dialog, and the app polls every 5 minutes — so an
uncached read meant that dialog every 5 minutes on any build whose signature
isn't in the item's ACL.

Three things drop the cached blob, and the first is the one that is easy to get
wrong. Every poll compares the Keychain item's **modification date**, which
costs nothing because reading attributes never prompts. Expiry alone would not
be enough: `claude login` swaps the identity in a slot without changing when the
token expires, and the token it replaces usually stays valid, so nothing would
401 and the app would keep reporting the previous account for hours. The other
two are the ordinary ones — the token nearing expiry, and a 401.

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

**Menu bar layout.** A grid of two rows, filled top-to-bottom then
left-to-right — three Claude profiles and Grok read as:

```
● cc0   ● cc2
● cc1   ● Grok 86
```

Two rows is the ceiling, and the menu bar sets it rather than taste: the row is
about 22pt and two 10.5pt lines already fill it, so a third would need roughly
7pt, past legible. Extra entries therefore widen the item instead of shrinking
it, and the fill is column-major so adding a profile pushes the layout wider
rather than reshuffling which row the existing ones sit on. Columns are aligned
with tab stops, since the labels differ in width and padding spaces would leave
the second column ragged.

**Width, and the notch.** macOS does not truncate a status item that no longer
fits — it hides it — so on a Mac with a notch a crowded menu bar makes items
disappear rather than shrink. The app keeps itself inside a budget of half the
menu bar's right-hand region (`auxiliaryTopRightArea`, the strip beside the
notch), dropping the per-model cap first and then the weekly figure if it would
overrun. Three profiles and Grok come to about 134pt against a 332pt budget on a
14" MacBook Pro, so in practice it never has to.

What the app cannot see is how much room *other* apps' items are taking, which
is what actually squeezes it. **Settings → Menu Bar → Detail** is the manual
lever: forcing "5-hour only" takes the same four entries down to about 84pt.
Anything dropped stays in the tooltip and the popover.

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

**The Grok row is missing or says `--`.** Run `grok login` in a terminal. If the
CLI is installed somewhere unusual, set its path in Settings → Grok — the app
does not consult `PATH`, because an app launched from Finder inherits launchd's
environment rather than a shell's.

**Settings won't open.** Fixed, but worth recording why: the settings window used
to be a SwiftUI `Settings` scene opened with the private `showSettingsWindow:`
selector. In an accessory app that never opens a window of its own, the scene is
not reliably instantiated, and the selector reports success either way — so the
failure was completely silent. The window is now built directly by the app
delegate, and opening it is deferred past the status menu's tracking session,
which otherwise swallows the request.

**Nothing in the menu bar.** `LSUIElement` must be `true` in
`ClaudeCodeUsageWidget/Info.plist`. The target sets `GENERATE_INFOPLIST_FILE = NO`
and points `INFOPLIST_FILE` at that file, so the plist wins — the
`INFOPLIST_KEY_LSUIElement` build setting is not consulted.

## Project layout

```
ClaudeCodeUsageWidget/
├── ClaudeCodeUsageApp.swift   # Lifecycle, status bar item, SwiftUI views
├── UsageMonitor.swift         # Endpoints, polling, parsing, degraded state
├── KeychainHelper.swift       # Profile discovery, token read/cache/refresh
└── GrokMonitor.swift          # Grok CLI over ACP, billing-period usage
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
