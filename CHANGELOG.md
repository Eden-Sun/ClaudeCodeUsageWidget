# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Menu bar icon color customization
- Widget for macOS Dashboard
- Siri Shortcuts integration
- iCloud sync for settings

## [2.6]

The work between 2.0 and 2.6 was never written down as it happened, and the
repository has a single commit, so there are no dates to recover for 2.1–2.5.
Everything that shipped in those versions is recorded here in one entry rather
than split across invented release dates. The version in `Info.plist` is 2.6
(build 8).

### Added
- **Multiple profiles.** Claude Code keys its credentials by config directory,
  and the app now discovers all of them: `~/.claude` keeps the bare service name
  `Claude Code-credentials`, and any other `CLAUDE_CONFIG_DIR` gets
  `-<first 8 hex of sha256(absolute directory path)>` appended. Each profile
  gets a column in the popover, a line in the menu bar, and a row under
  Settings → Profiles. Discovery reads Keychain *attributes* only, so it never
  raises an access prompt
- **Stacked menu bar.** One line per profile when there is more than one, at a
  smaller size so two lines stay narrower than the old single line — an
  over-wide item pushes the menu bar behind the notch. Primary profile first,
  monospaced digits so the width doesn't shuffle on every refresh
- **"Menu bar shows" picker** in the right-click menu, mirrored by
  Settings → Menu Bar → Show account. The choice is persisted
  (`primary_account_service` in UserDefaults) and survives relaunches
- **Self-service token refresh.** The CLI only renews a token while it is
  running, so an idle profile used to sit on a dead one. The app now runs the
  grant itself against `POST https://api.anthropic.com/v1/oauth/token` and
  writes the rotated blob back to the same Keychain item — the server rotates
  the refresh token, so the write-back is not optional. Also triggered by a 401
  on a token that has not formally expired, once per poll
- **`renewalNotSaved` error**: a refresh that succeeded but whose new token
  could not be written back is reported separately ("Session renewed but the new
  token could not be saved") instead of being conflated with a failed refresh —
  using it would leave the CLI holding a token the server has already retired
- **Stale readings.** A profile that can't be polled keeps its last successful
  snapshot on screen, badged with the reason, how old the reading is, and the
  exact command that puts it back in sync (`claude login`, or
  `CLAUDE_CONFIG_DIR=… claude` for a non-default profile), rather than blanking
- Account email alongside the plan label, from `GET /api/oauth/profile`. The
  identity cache is keyed on a fingerprint of the access token, so logging a
  profile in as a different account is noticed instead of showing the previous
  email until relaunch
- Fable's weekly cap appended to the menu bar on Max plans
- Opening the popover refreshes any profile whose reading is over 30 seconds old

### Changed
- The weekly figure is appended to the menu bar whenever the response carries a
  `seven_day` window, rather than only when weekly was the tighter constraint
- Every poll rediscovers profiles, so logging one in or out is picked up without
  restarting the app
- A poll is retried unless *every* profile has a recent, error-free snapshot;
  keying that off the primary alone left a broken secondary profile unretried
- The popover widens with the profile count and scrolls horizontally past three
  columns instead of squeezing every column narrower
- `LSUIElement` is `true` again, so the app is menu-bar-only; it had regressed
  to `false`, which put a Dock icon and an app menu on screen
- Settings → About reads the version from the bundle instead of a hardcoded
  string that had to be edited by hand
- `CFBundleShortVersionString` bumped to 2.6 (build 8)

### Fixed
- `scripts/make-dmg.sh` died silently on any machine without a codesigning
  identity, *after* the full Release build: `security` reporting "0 valid
  identities found" makes `grep` exit 1, and under `set -euo pipefail` an
  assignment fed by a command substitution takes that status. The ad-hoc branch
  is reachable again, and the script now prints which identity it chose
- `scripts/make-dmg.sh` reported a corrupt image as a successful build —
  `hdiutil verify … && echo` lets the verification fail without tripping
  `set -e`. A failed verification is now fatal

## [2.0] - 2026-08-12

Unblocks the project: subscription usage is readable after all, just not from
where the earlier investigation looked.

### Added
- Read the 5-hour and weekly usage windows from `GET /api/oauth/usage` on
  `api.anthropic.com`, authenticated with the OAuth token Claude Code already
  stores in the login Keychain (service `Claude Code-credentials`)
- Surface per-model weekly caps from the response's `limits[]` array, which the
  top-level `five_hour` / `seven_day` fields don't expose
- Menu bar shows the weekly percentage alongside the 5-hour one when weekly is
  the tighter constraint
- Plan name from `GET /api/oauth/profile`
- `scripts/make-dmg.sh` — builds Release and packages a `.dmg` via `hdiutil`
  (no external tooling); output lands in `dist/`

### Changed
- All figures now show **remaining** headroom rather than consumption, including
  the colour thresholds (green above 50% left, yellow above 20%, red below)
- Bumped `CFBundleShortVersionString` to 2.0, which had been left at 1.0
- No API key, organization ID, or session cookie is required any more — the
  setup window is gone
- The token is re-read from the Keychain on every poll, so a CLI-side refresh is
  picked up without restarting the app
- Rewrote `UsageMonitor` around utilization percentages instead of the previous
  token/cost model, which never had a working data source

### Removed
- The claude.ai scraping path (it 403s behind Cloudflare) and the Admin API
  probing that returned 404s
- `PENDING.md`; `STATUS.md` now documents the working integration
- Everything 1.1 built on top of an API key, along with the seven source files
  that implemented it — `AppConfig.swift`, `LaunchAtLoginHelper.swift`,
  `NotificationManager.swift`, `PreferencesView.swift`, `StatisticsView.swift`,
  `UsageHistoryManager.swift` and `UsageView.swift`. Concretely, these are gone:
  - Smart Notifications (the 75% / 85% / 95% threshold alerts)
  - Usage Statistics, the analytics window and CSV export
  - Usage History tracking (the stored 1000-entry log)
  - Launch at Login
  - The Preferences window, including the API key field and the update-interval
    slider — the poll interval is now a constant in `UsageMonitor.swift`

### Notes
- Both endpoints are undocumented — they're the ones Claude Code itself calls.
  Parsing is lenient so a changed field degrades one row rather than failing the
  fetch.
- The Keychain blob's `subscriptionType` is **not** used for the plan name: it
  reported `pro` for a Max account. The profile endpoint is authoritative.
- **Correction (2026-09-04):** this entry originally listed "optional manual
  token override in Settings". No such control ever shipped — there is no text
  field anywhere in the app. The only setting is which profile the menu bar
  tracks.

## [1.1.0] - 2025-01-20

> **Historical entry.** Everything below was removed in 2.0 and none of it
> exists in the current app: there are no notifications, no statistics window,
> no CSV export, no launch-at-login toggle, no usage history and no preferences
> window, and the app has not used an API key since 2.0.

### Added
- **Smart Notifications**: Receive alerts at 75%, 85%, and 95% usage thresholds
- **Usage Statistics**: Beautiful charts showing usage trends over 7, 14, or 30 days
- **Data Export**: Export usage history to CSV format
- **Launch at Login**: Automatically start the app when macOS boots
- **Comprehensive Preferences Window**: Dedicated window for all settings
  - API key management
  - Notification preferences
  - Update interval customization
  - Launch at login toggle
  - Data management options
- **Right-Click Menu**: Quick access to Statistics, Preferences, and Refresh
- **Usage History Tracking**: Automatic logging of all usage checks
- **Usage Statistics Dashboard**:
  - Average usage percentage
  - Peak usage tracking
  - Total checks counter
  - Tracking streak display
  - Interactive usage trend charts
- **Notification Manager**: Handles all notification logic with threshold-based alerts
- **KeychainHelper**: Secure API key storage and migration from UserDefaults
- **LaunchAtLoginHelper**: System integration for auto-start

### Improved
- Simplified main popover view (moved settings to preferences window)
- Better separation of concerns with dedicated view controllers
- Enhanced security with Keychain integration
- More user-friendly preferences interface

### Technical
- Added NotificationManager for smart alerts
- Added UsageHistoryManager for data tracking and export
- Added StatisticsView with Charts framework integration
- Added PreferencesView with comprehensive settings
- Added LaunchAtLoginHelper for macOS integration
- Centralized configuration in AppConfig.swift

## [1.0.0] - 2025-01-20

> **Historical entry.** 1.0's data source — an API key and a request-count
> model — never had a working backend and was replaced wholesale in 2.0.

### Added
- Initial release
- Menu bar integration showing usage percentage
- Real-time usage monitoring with 5-minute refresh interval
- Color-coded usage indicators (green → yellow → orange → red → critical)
- Circular progress indicator in popover
- Detailed usage statistics display
- Settings panel for API key configuration
- Manual refresh capability
- Error handling and retry logic
- Support for macOS 13.0 (Ventura) and later

### Features
- **Visual Indicators**: Color-coded dots show usage level at a glance
- **Detailed Popover**: Click menu bar icon to see full statistics
- **Usage Breakdown**: Shows used, remaining, and total limit
- **Reset Timer**: Displays when usage will reset
- **Auto-refresh**: Background polling every 5 minutes
- **Error Handling**: Clear error messages with retry option

### Technical
- Built with Swift 5.9
- Uses AppKit for menu bar integration
- SwiftUI for popover interface
- Native macOS app with minimal resource usage
- Secure local storage for API key

## Version History

- **1.0.0** - Initial public release
- **1.1.0** - Notifications, statistics and preferences (all removed in 2.0)
- **2.0** - Rebuilt on Claude Code's OAuth token and the subscription usage endpoint
- **2.6** - Multiple profiles, stacked menu bar, self-service token refresh
  (2.1–2.5 are not recorded separately; see the [2.6] entry)
