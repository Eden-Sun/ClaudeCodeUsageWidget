# Quick Start Guide

Get up and running with Claude Code Usage Widget in 5 minutes!

## Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later
- Claude Code installed and signed in (`claude login`) on a Pro or Max plan

There is **no API key**. The app reads the OAuth token Claude Code already keeps
in your login Keychain, so if `claude` works in your terminal, you are ready.

## Step 1: Open the Project

```bash
# Clone or navigate to the project directory
cd ClaudeCodeUsageWidget

# Open in Xcode
open ClaudeCodeUsageWidget.xcodeproj
```

Or simply double-click `ClaudeCodeUsageWidget.xcodeproj` in Finder.

## Step 2: Build and Run

1. In Xcode, select your Mac as the build target
2. Press `Cmd + R` or click the Play button
3. The app will build and launch
4. You'll see `● --` appear in your menu bar (top right) until the first poll
   lands

## Step 3: Allow Keychain Access

macOS asks whether the app may read the `Claude Code-credentials` Keychain item.

- Click **Always Allow**
- If you have more than one Claude Code profile, you'll be asked once per
  profile — the extra ones live under `Claude Code-credentials-<8 hex>`

If you click Deny, the popover shows "Credentials unreadable". Grant access
again in Keychain Access → the item → Access Control.

> Ad-hoc signed builds are pinned to the binary's hash, so **every rebuild from
> Xcode re-asks**. `./scripts/make-dmg.sh` signs with a real certificate when
> one is available, which makes "Always Allow" stick across rebuilds.

## Step 4: Read Your Usage

Every number is what you have **left**, not what you've used.

- **Menu bar**: remaining 5-hour percentage, then the weekly percentage, then
  Fable's weekly cap on Max plans. One line per profile if you have several.
  Hover for a labelled breakdown
- **Left-click**: the popover — a big 5-hour gauge, a bar per weekly cap
  (including per-model ones like Fable), reset times, and one column per profile
- **Right-click**: Refresh, "Menu bar shows" (with two or more profiles),
  Settings, Quit

## Understanding the Colors

The dot follows the **remaining** 5-hour headroom:

| Color | Remaining | Meaning |
|-------|-----------|---------|
| ● Green | more than 50% | Plenty available |
| ● Yellow | 20–50% | Getting close |
| ● Red | 20% or less | Nearly at the limit |

## Tips

### Refresh Manually
- Click the ↻ button in the popover, or right-click → Refresh
- Automatic refresh happens every 5 minutes
- Just opening the popover refreshes anything older than 30 seconds

### Pick What the Menu Bar Shows
With more than one Claude Code profile, right-click → **Menu bar shows**, or
open Settings → Menu Bar → **Show account**. The choice is remembered.

### Change Update Frequency
Edit `UsageMonitor.swift` and change:
```swift
private let updateInterval: TimeInterval = 300 // 5 minutes
```
To any value in seconds (e.g., `60` for 1 minute, `600` for 10 minutes), then
rebuild. There is no setting for this in the UI.

## Troubleshooting

### Can't see the widget
- Make sure the app is running (check Activity Monitor)
- The app is menu-bar-only (`LSUIElement`), so there is no Dock icon to look for
- If the menu bar is crowded, quit something else — macOS hides overflow items

### "No Claude Code login found"
- Run `claude login` in a terminal, then Refresh

### A column says "signed out" or shows a stale badge
- The popover prints the exact command for that profile — `claude login`, or
  `CLAUDE_CONFIG_DIR=… claude` for a non-default one
- Stale means the numbers are real but couldn't be refreshed this poll; they
  stay on screen with their age rather than disappearing

### No data showing
- Wait a few seconds for the first fetch
- Click Refresh to try again
- Check the error message if one appears

## Next Steps

- **Customize**: Explore the code and make it your own
- **Contribute**: Found a bug? Have an idea? Open an issue or PR!
- **Share**: Help others by sharing your experience

## Need Help?

- Check the full [README.md](README.md)
- [STATUS.md](STATUS.md) documents the endpoints and the Keychain lookup
- Open an [issue](https://github.com/Eden-Sun/ClaudeCodeUsageWidget/issues)

---

Enjoy monitoring your Claude Code usage! 🚀
