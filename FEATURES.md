# Features Guide

Complete guide to all features in Claude Code Usage Widget.

> Everything the app displays is **remaining** headroom, never consumption. A
> figure of `35` means 35% of that window is still available.

## Table of Contents
- [Menu Bar Display](#menu-bar-display)
- [Usage Popover](#usage-popover)
- [Right-Click Menu](#right-click-menu)
- [Multiple Profiles](#multiple-profiles)
- [Token Handling](#token-handling)
- [Settings](#settings)
- [Privacy](#privacy)

## Menu Bar Display

The app lives in your macOS menu bar — no Dock icon, no app menu
(`LSUIElement`).

**What you see**, per profile, always in this order:

1. A colour-coded dot
2. Remaining 5-hour percentage
3. Remaining weekly percentage, whenever the response carries a `seven_day`
   window
4. Fable's remaining weekly cap, on Max plans only

So `● 68 41` reads as "68% of the 5-hour window and 41% of the week left".
Before the first successful poll, or when nothing could be read, it shows
`● --`.

**Colour meanings** (driven by the 5-hour window's *remaining* percentage):

- **● Green**: more than 50% left
- **● Yellow**: 20–50% left
- **● Red**: 20% or less left

**Tooltip**: hover for a labelled breakdown — profile name and plan, email,
`5-hour: N% left`, `Weekly: N% left`, and a line per per-model cap.

**Layout notes**: digits are monospaced so the item doesn't shuffle width as the
numbers tick, and with two or more profiles the lines are stacked at a smaller
size so the whole block still fits a notched Mac's menu bar.

## Usage Popover

Left-click the menu bar item.

**Shows**, per profile column:
- Profile name, plan label, and a menu bar glyph on the profile the menu bar
  tracks
- Account email (selectable, truncated in the middle so the domain stays
  visible)
- A large circular gauge: remaining 5-hour percentage and its reset time
- A bar per weekly cap — "Weekly" from the top-level window, plus one per
  per-model cap (e.g. "Weekly · Fable") — each with its own reset time

**Actions:**
- **↻ button**: refresh every profile now
- **Auto-updates**: every 5 minutes
- **On open**: anything older than 30 seconds is refreshed automatically
- **Settings** and **Quit** in the footer

**Stale readings**: if a profile couldn't be refreshed but has a previous
reading, the column keeps the numbers and adds an orange notice with the reason,
how old the reading is, and the exact command that fixes it. The usage windows
move slowly enough that an hour-old reading still tells you where you stand.

**Signed-out profiles**: a profile with nothing to show gets a quiet placeholder
and the same login command rather than an error.

## Right-Click Menu

Right-click the menu bar icon for:

- **Refresh** (⌘R) — poll every profile now
- **Menu bar shows** — one checkable entry per profile; only appears with two or
  more. Picks which profile the menu bar leads with
- **Settings…** (⌘,)
- **Quit** (⌘Q)

## Multiple Profiles

Claude Code keys its credentials by config directory, and the app follows.

- `~/.claude` is the **default** profile
- Any other `CLAUDE_CONFIG_DIR` gets its own Keychain slot, named
  `Claude Code-credentials-<first 8 hex of sha256 of the directory path>`
- The label comes from the directory name: `~/.claude-ccompany` → `ccompany`

Every profile with credentials shows up on its own — there is nothing to add or
configure. Log one in and it appears; log it out and it goes away. Discovery
runs on every poll and reads Keychain *attributes* only, so it never triggers an
access prompt on its own.

In the UI, each profile gets a popover column (the row scrolls horizontally past
three), a menu bar line, and a row under Settings → Profiles with its status:
`active`, `stale`, or `signed out`.

## Token Handling

**Where the token comes from**: the OAuth blob Claude Code stores in your login
Keychain. There is no API key, no organization ID and no session cookie
anywhere in this app.

**Re-read every poll**, so a refresh the CLI performs in the background is
picked up without restarting.

**Renewed by the app when needed**: the CLI only renews a token while it is
running, so a profile left idle sits on an expired one. The app runs the refresh
grant itself (`POST /v1/oauth/token`) and writes the rotated token straight back
to the same Keychain item. It also retries once when a token that hasn't
formally expired is rejected with a 401.

**Failure modes you may see**, each with its own message:
- *Credentials unreadable* — Keychain access was denied
- *Session expired* — no usable refresh token left
- *Session expired and could not be renewed* — the grant was refused; the
  profile needs a re-login
- *Session renewed but the new token could not be saved* — the refresh worked
  but the write-back failed, so the app refuses to use a token the CLI doesn't
  know about
- *Token rejected (401)* / *Usage API returned HTTP N* / network and decoding
  errors

## Settings

Open with ⌘, or the Settings button in the popover. There are exactly two
sections plus About:

**Menu Bar** — *Show account*: which profile the menu bar tracks. The popover
always lists every profile; this only picks the one the menu bar leads with. The
choice is persisted and survives relaunches.

**Profiles** — a read-only list of every discovered profile with its plan,
email, config directory and status. Profiles come from Claude Code itself;
there is nothing to configure here.

**About** — version and a one-line description.

There is no API key field, no refresh-interval slider, no notification settings
and no launch-at-login toggle. To change the poll interval, edit
`updateInterval` in `UsageMonitor.swift` and rebuild.

## Privacy

- No credentials of its own: it reads the tokens Claude Code already keeps in
  your login Keychain, and a renewed token is written back to that same item
- Talks only to `api.anthropic.com`
- No usage history is stored, no analytics, no telemetry, no third parties
- The only thing it persists is one preference recording which profile the menu
  bar tracks. Poll results are logged to the local unified log (profile label
  and remaining percentage — never a token) and go nowhere else

## Support

Need help? Check:
- [README.md](README.md) - Full documentation
- [QUICKSTART.md](QUICKSTART.md) - 5-minute setup
- [STATUS.md](STATUS.md) - Endpoints, Keychain lookup and refresh flow
- [GitHub Issues](https://github.com/Eden-Sun/ClaudeCodeUsageWidget/issues) - Report bugs

---

**Enjoy monitoring your Claude Code usage!** 🚀
