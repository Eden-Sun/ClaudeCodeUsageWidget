# Quick Start Guide

Get up and running with Claude Code Usage Widget in 5 minutes!

## Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later
- Claude API key from [Anthropic Console](https://console.anthropic.com)

## Step 1: Get Your API Key

1. Visit [https://console.anthropic.com](https://console.anthropic.com)
2. Sign in or create an account
3. Go to "API Keys" section
4. Click "Create Key"
5. Copy the generated API key (starts with `sk-ant-`)
6. Keep it safe - you'll need it in Step 4

## Step 2: Open the Project

```bash
# Clone or navigate to the project directory
cd ClaudeCodeUsageWidget

# Open in Xcode
open ClaudeCodeUsageWidget.xcodeproj
```

Or simply double-click `ClaudeCodeUsageWidget.xcodeproj` in Finder.

## Step 3: Build and Run

1. In Xcode, select your Mac as the build target
2. Press `Cmd + R` or click the Play button
3. The app will build and launch
4. You'll see "..." appear in your menu bar (top right)

## Step 4: Configure API Key

1. Click the "..." icon in your menu bar
2. A popover will appear
3. Click the gear icon (⚙️) in the top-right corner
4. Paste your API key from Step 1
5. Click "Save"

## Step 5: View Your Usage

- The menu bar icon will update with your current usage percentage
- Click the icon to see detailed statistics:
  - Circular progress indicator
  - Used requests
  - Remaining requests
  - Total limit
  - Time until reset

## Understanding the Colors

| Color | Usage | Meaning |
|-------|-------|---------|
| ● Green | 0-24% | Plenty available |
| ● Yellow | 25-49% | Half used |
| ● Orange | 50-74% | Getting close |
| ● Red | 75-89% | Nearly at limit |
| ⚠️ Purple | 90-100% | Critical |

## Tips

### Refresh Manually
- Click the "Refresh" button in the popover to update immediately
- Automatic refresh happens every 5 minutes

### Check for Errors
- If you see an error message, check:
  - Your internet connection
  - Your API key is correct
  - The API endpoint is accessible

### Change Update Frequency
Edit `UsageMonitor.swift` and change:
```swift
private let updateInterval: TimeInterval = 300 // 5 minutes
```
To any value in seconds (e.g., `60` for 1 minute, `600` for 10 minutes)

## Troubleshooting

### Can't see the widget
- Make sure the app is running (check Activity Monitor)
- Look for "ClaudeCodeUsageWidget" in the menu bar
- Try quitting and restarting

### "API key not set" error
- Open settings (gear icon)
- Verify you entered the full API key
- Make sure there are no extra spaces

### No data showing
- Wait a few seconds for the first fetch
- Click "Refresh" to try again
- Check the error message if one appears

## Next Steps

- **Customize**: Explore the code and make it your own
- **Contribute**: Found a bug? Have an idea? Open an issue or PR!
- **Share**: Help others by sharing your experience

## Need Help?

- Check the full [README.md](README.md)
- Open an [issue](https://github.com/yourusername/claude-code-usage-widget/issues)
- Review [Anthropic's API docs](https://docs.anthropic.com)

---

Enjoy monitoring your Claude Code usage! 🚀
