# Claude Code Usage Widget for macOS

A native macOS menu bar app that shows how much of your Claude subscription
limits you have **left** — the 5-hour session window and the weekly caps — in
real time. Built with Swift and SwiftUI.

## Features

- **Menu Bar Integration**: Remaining 5-hour headroom, followed by the weekly figure whenever the response carries one (and, on Max plans, Fable's weekly cap)
- **Both Windows**: 5-hour session window and the weekly cap, each with its reset time
- **Per-Model Caps**: Surfaces the scoped weekly limits (e.g. Fable, Opus) that the top-level numbers hide
- **Multiple Profiles**: Every `CLAUDE_CONFIG_DIR` Claude Code has logged in gets its own column in the popover and its own line in the menu bar; pick which one the menu bar leads with
- **Zero Configuration**: Reuses the login Claude Code already has — no API key, no org ID, no cookie
- **Auto Refresh**: Polls every 5 minutes, and renews an expired OAuth token itself rather than waiting for the CLI
- **Colour Coding**: Green above 50% left, yellow 20–50% left, red below 20%
- **Low Resource Usage**: Native Swift app with a minimal footprint

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (for building)
- Claude Code installed and signed in (`claude login`) on a Pro or Max plan

## Installation

### Option 1: Build from Source

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/claude-code-usage-widget.git
   cd claude-code-usage-widget
   ```

2. **Open in Xcode**
   ```bash
   open ClaudeCodeUsageWidget.xcodeproj
   ```

3. **Build and Run**
   - Select your Mac as the build target
   - Press `Cmd + R` to build and run
   - Or go to `Product > Run`

4. **Allow Keychain access**
   - On first launch macOS asks whether the app may read the
     `Claude Code-credentials` Keychain item
   - Click **Always Allow** — this is the login token the app reads to
     authenticate; there is nothing else to configure

### Option 2: Build a DMG

```bash
./scripts/make-dmg.sh     # -> dist/ClaudeCodeUsageWidget-<version>.dmg
```

Builds Release, stages the app next to an `/Applications` symlink, and produces
a compressed disk image. No external tooling required.

If the machine has a codesigning certificate the script re-signs with the first
one `security find-identity` lists — set `SIGN_IDENTITY` to choose another; the
script prints the one it used. With no certificate at all it leaves the ad-hoc
signature in place and says so.

> Either way there's no Developer ID and no notarization on this project, so
> Gatekeeper blocks the result on any Mac other than the one that built it. On
> another machine, right-click the app → Open, or run
> `xattr -dr com.apple.quarantine /Applications/ClaudeCodeUsageWidget.app`.
> For real distribution, set `DEVELOPMENT_TEAM`, sign with a Developer ID, and
> notarize with `notarytool`.
>
> Signing with a certificate is worth it even locally: an ad-hoc signature is
> pinned to the binary's cdhash, so every rebuild looks like a new app to the
> Keychain and macOS re-prompts for credential access.

## Configuration

There is none. The app reads the OAuth tokens Claude Code stores in your login
Keychain, so the accounts `claude` is signed into are the accounts you see.

Claude Code keys its credentials by config directory, and the app follows: each
`CLAUDE_CONFIG_DIR` you have logged in gets its own Keychain slot, its own
column in the popover, and its own line in the menu bar. The only setting is
which profile the menu bar leads with — **Settings → Menu Bar → Show account**,
or right-click the menu bar item and pick one under **Menu bar shows**. The
choice is remembered across relaunches.

### Customizing Update Interval

By default, the app checks usage every 5 minutes. To change this:

1. Open `UsageMonitor.swift`
2. Find the line: `private let updateInterval: TimeInterval = 300`
3. Change `300` to your desired interval in seconds
4. Rebuild the app

## Usage Indicators

Every number the app shows is **remaining** headroom, not consumption. The dot
changes colour with the 5-hour window's remaining percentage:

- **🟢 Green** (more than 50% left)
- **🟡 Yellow** (20–50% left)
- **🔴 Red** (20% or less left)

## How It Works

1. **Status Bar Item**: One line per profile — remaining 5-hour, then weekly, then Fable's weekly cap on Max plans
2. **Background Monitoring**: Polls the usage endpoint every 5 minutes; opening the popover refreshes anything older than 30 seconds
3. **Auth**: Re-reads Claude Code's OAuth token from the login Keychain on every poll, so a CLI-side refresh is picked up automatically. If the token has expired, the app runs the refresh grant itself and writes the rotated token back to the same Keychain item
4. **Visual Update**: Updates the menu bar title, its tooltip, and the popover
5. **Stale Readings**: A profile that can't be polled keeps its last good numbers on screen, labelled with the reason and the command that fixes it, instead of blanking

## API Integration

```
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer <Claude Code OAuth access token>
anthropic-beta: oauth-2025-04-20
```

Returns `five_hour` / `seven_day` utilization percentages plus a `limits` array
carrying per-model weekly caps. The plan name and email come from
`GET /api/oauth/profile`. An expired access token is renewed with
`POST /v1/oauth/token` (`grant_type=refresh_token`) before either call.

> **Note**: these endpoints are undocumented — they're what Claude Code itself
> calls — and may change without notice. Parsing is deliberately lenient so a
> changed field degrades one row rather than breaking the app. See
> [STATUS.md](STATUS.md) for the full response shape.

## Development

### Project Structure

```
ClaudeCodeUsageWidget/
├── ClaudeCodeUsageWidget/
│   ├── ClaudeCodeUsageApp.swift    # App lifecycle, status bar, SwiftUI views
│   ├── UsageMonitor.swift          # Usage/profile endpoints, polling, parsing
│   ├── KeychainHelper.swift        # Reads Claude Code's OAuth token
│   └── Info.plist                  # App configuration
├── ClaudeCodeUsageWidget.xcodeproj/
└── README.md
```

### Key Components

**ClaudeCodeUsageApp.swift**
- App entry point and lifecycle management
- Status bar item (one stacked line per profile), tooltip and right-click menu
- SwiftUI views: circular 5-hour gauge, weekly/scoped bars, per-profile columns, settings

**UsageMonitor.swift**
- Usage and profile endpoint calls, one set per discovered profile
- Data model and lenient JSON parsing
- Background polling, last-good snapshots and error states

**KeychainHelper.swift**
- Discovers every Claude Code profile from the Keychain's service names
- Reads each profile's OAuth token from the login Keychain
- Runs the OAuth refresh grant and writes the rotated token back

### Building for Distribution

1. **Archive the app**
   - In Xcode: `Product > Archive`
   
2. **Notarize (for distribution outside App Store)**
   - Sign with your Developer ID
   - Submit for notarization
   - Staple the notarization ticket

3. **Create DMG**
   - `./scripts/make-dmg.sh` (uses `hdiutil`; no external tooling)
   - Include installation instructions

## Troubleshooting

### "No Claude Code login found"
- Run `claude login` in a terminal, then hit Refresh
- If macOS asked about Keychain access and you clicked Deny, grant it again in
  Keychain Access → `Claude Code-credentials` → Access Control (a non-default
  profile lives under `Claude Code-credentials-<8 hex>`)

### "Session expired and could not be renewed" / 401
- The app renews expired access tokens on its own, so this means the refresh
  token has lapsed too (~2 weeks) or the grant was refused
- Run the command the popover shows for that profile — `claude login`, or
  `CLAUDE_CONFIG_DIR=… claude` for a non-default one
- Until then the profile keeps showing its last good numbers, marked stale

### "Session renewed but the new token could not be saved"
- The refresh succeeded but the rotated token couldn't be written back to the
  Keychain, which would leave the CLI holding a retired token — so the app
  refuses to use it
- Check the app's access to that Keychain item, then run `claude login`

### No data showing
- Check your internet connection
- Confirm `curl https://api.anthropic.com/api/oauth/usage -H "Authorization: Bearer $TOKEN" -H "anthropic-beta: oauth-2025-04-20"` returns 200

### Widget not appearing in menu bar
- Make sure `LSUIElement` is set to `true` in `ClaudeCodeUsageWidget/Info.plist`.
  The target sets `GENERATE_INFOPLIST_FILE = NO` and points `INFOPLIST_FILE` at
  that file, so the plist wins — the `INFOPLIST_KEY_LSUIElement` build setting
  is not consulted
- Restart the app

### High CPU usage
- Increase the `updateInterval` to poll less frequently
- Check for network issues causing repeated failed requests

## Future Enhancements

- [ ] Menu bar icon color customization
- [ ] Widget for macOS Dashboard
- [ ] Siri Shortcuts integration
- [ ] iCloud sync for settings
- [ ] Advanced analytics and predictions
- [ ] Team usage tracking
- [ ] Custom notification sounds

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Built with Swift and AppKit
- Uses Anthropic Claude API
- Inspired by the need for easy usage monitoring

## Support

If you encounter any issues or have questions:
- Open an [Issue](https://github.com/yourusername/claude-code-usage-widget/issues)
- Check existing issues for solutions
- Consult the [Anthropic API Documentation](https://docs.anthropic.com)

## Privacy

This app:
- Stores no credentials of its own — it reads the tokens Claude Code already
  keeps in your login Keychain, and a token it renews is written straight back
  to the same Keychain item
- Communicates directly with Anthropic's API
- Does not collect or transmit any other data
- Does not include analytics or tracking

---

**Note**: This is an unofficial app and is not affiliated with Anthropic. Use at your own discretion.
