# Features Guide

Complete guide to all features in Claude Code Usage Widget.

## Table of Contents
- [Basic Features](#basic-features)
- [Advanced Features](#advanced-features)
- [Preferences](#preferences)
- [Statistics](#statistics)
- [Notifications](#notifications)
- [Data Management](#data-management)

## Basic Features

### Menu Bar Display

The app lives in your macOS menu bar, showing your current usage at a glance.

**What you see:**
- Color-coded dot indicator (● green/yellow/orange/red or ⚠️ critical)
- Usage percentage (e.g., "45%")

**Color meanings:**
- **● Green** (0-24%): Plenty of requests available
- **● Yellow** (25-49%): About halfway through your limit
- **● Orange** (50-74%): Getting close to your limit
- **● Red** (75-89%): Approaching your limit
- **⚠️ Purple** (90-100%): Critical - at or near limit

### Usage Popover

Click the menu bar icon (left-click) to see detailed usage information.

**Shows:**
- Large circular progress indicator
- Current usage percentage
- Number of requests used
- Number of requests remaining
- Total request limit
- Time until usage resets

**Actions:**
- **Refresh button**: Manually update usage data
- **Auto-updates**: Every 5 minutes by default

### Right-Click Menu

Right-click the menu bar icon for quick access to:
- **Open Usage**: Show the main popover
- **Statistics**: Open usage statistics window
- **Preferences**: Open preferences window
- **Refresh Now**: Immediately update usage data
- **Quit**: Exit the application

## Advanced Features

### Smart Notifications

Get notified before you hit your usage limit.

**When you're notified:**
- 75% usage: "🟡 Warning: 75% used"
- 85% usage: "🔴 High usage: 85% used"
- 95% usage: "⚠️ Critical: 95% used!"

**Features:**
- Notifications only sent once per threshold
- Won't spam you with repeated alerts
- Includes remaining request count
- Different notification sounds for severity

**Enable in Preferences:**
1. Open Preferences (⌘,)
2. Toggle "Enable usage alerts"
3. Grant notification permission when prompted
4. Click "Send Test Notification" to verify

### Usage Statistics

Track your usage patterns over time with beautiful visualizations.

**Access:** Right-click menu bar → Statistics

**Shows:**
- **Average Usage**: Your typical usage percentage
- **Peak Usage**: Highest usage reached
- **Total Checks**: Number of times usage was checked
- **Tracking Streak**: Consecutive days with usage data

**Usage Trend Chart:**
- Interactive line chart showing usage over time
- Select timeframe: 7, 14, or 30 days
- Gradient visualization for easy reading
- Automatic date formatting

**Export to CSV:**
- Click "Export to CSV" button
- File saved to Downloads folder
- Opens Finder to file location
- Contains: timestamp, used, limit, percentage, reset date

### Launch at Login

Start the app automatically when you log in to macOS.

**Enable in Preferences:**
1. Open Preferences
2. Toggle "Launch at login"
3. Status shows current state

**Benefits:**
- Never forget to monitor your usage
- Always up-to-date information
- Seamless integration with macOS

## Preferences

### API Configuration

**Set your API Key:**
1. Open Preferences (⌘, or right-click → Preferences)
2. Enter your Claude API key in the secure field
3. Key is automatically saved when you close preferences

**Get an API Key:**
- Click "Open Anthropic Console" button
- Creates/manages keys at console.anthropic.com
- Copy key and paste into preferences

**Security:**
- Keys stored in macOS Keychain (not plain text)
- Secure encryption
- Can be removed at any time

### Update Settings

**Refresh Interval:**
- Slider from 1 to 10 minutes
- Default: 5 minutes
- Lower = more API calls = more current data
- Higher = fewer API calls = less battery/network usage

**How it works:**
- App polls Claude API at this interval
- Updates menu bar and popover
- Runs in background
- Minimal resource usage

### Notification Settings

**Toggle notifications:**
- Enable/disable all usage alerts
- Test notifications before going live
- Three severity levels (75%, 85%, 95%)

**Notification permissions:**
- Requested on first enable
- Can be changed in System Settings
- Shows banner and plays sound
- Persists between app launches

### Startup Options

**Launch at Login:**
- Toggle to enable/disable
- Uses macOS SMAppService (macOS 13+)
- Falls back to legacy API on older systems
- Shows current status

### Data Management

**Clear All Data:**
- Removes API key from Keychain
- Resets all preferences
- Clears usage history
- Removes all notifications
- Disables launch at login

**Warning:** This action cannot be undone!

## Statistics

### Overview Cards

Four cards showing key metrics:

**Average Usage:**
- Mean usage percentage across all checks
- Helps identify typical usage patterns

**Peak Usage:**
- Highest usage percentage recorded
- Alerts you to usage spikes

**Total Checks:**
- Number of times usage was fetched
- Shows app activity level

**Tracking Streak:**
- Consecutive days with usage data
- Motivates consistent monitoring

### Usage Trend Chart

**Interactive Chart:**
- Line chart with gradient fill
- X-axis: Time (auto-formatted)
- Y-axis: Usage percentage (0-100%)
- Smooth curve interpolation

**Timeframe Selection:**
- 7 days: Last week
- 14 days: Last two weeks
- 30 days: Last month

**What it shows:**
- Usage patterns over time
- Spikes and trends
- Historical context

### Data Export

**CSV Export:**
- One click to export all history
- Saved to Downloads folder
- Filename includes timestamp
- Can be opened in Excel, Numbers, Google Sheets

**CSV Format:**
```
Timestamp,Used,Limit,Percentage,Reset Date
2025-01-20T10:30:00Z,450,1000,45.00,2025-01-21T00:00:00Z
```

**Use cases:**
- Track usage over long periods
- Create custom reports
- Share with team
- Analyze in spreadsheet apps

## Notifications

### How They Work

**Threshold-Based:**
- Monitors usage percentage
- Triggers at specific thresholds
- Won't repeat same threshold

**Smart Logic:**
- Only notifies when crossing threshold UP
- Resets when usage drops below all thresholds
- Prevents notification spam

### Notification Levels

**Warning (75%):**
- Yellow indicator
- "Warning: 75% used"
- Default notification sound
- Early heads-up

**High Usage (85%):**
- Orange indicator
- "High usage: 85% used"
- Default notification sound
- Time to be careful

**Critical (95%):**
- Red indicator
- "⚠️ Critical: 95% used!"
- Critical notification sound
- Immediate attention needed

### Managing Notifications

**Enable/Disable:**
- Toggle in Preferences
- Takes effect immediately
- Persists between launches

**Test Notifications:**
- Send test to verify setup
- Check notification center
- Adjust system settings if needed

**System Settings:**
- Control notification style
- Set Do Not Disturb exceptions
- Customize sounds and alerts

## Data Management

### Usage History

**Automatic Tracking:**
- Every usage check is logged
- Stores up to 1000 entries
- Oldest entries auto-removed
- Persists between app launches

**What's Stored:**
- Timestamp of check
- Requests used
- Request limit
- Usage percentage
- Reset date (if available)

### Privacy

**Local Storage:**
- All data stored on your Mac
- No cloud sync (yet)
- No data sent to third parties
- You control your data

**API Key Security:**
- Stored in macOS Keychain
- Encrypted at rest
- Only accessible by this app
- Can be removed anytime

### Clearing Data

**What gets cleared:**
- API key from Keychain
- All preferences
- Complete usage history
- All notifications
- Launch at login setting

**What doesn't get cleared:**
- The app itself
- Exported CSV files
- System notification permissions

**How to clear:**
1. Open Preferences
2. Scroll to "Data Management"
3. Click "Clear All Data"
4. Confirm in alert dialog

## Tips & Tricks

### Keyboard Shortcuts

- **⌘,** - Open Preferences
- **⌘R** - Refresh Now (when popover is open)
- **⌘Q** - Quit App

### Optimal Settings

**For frequent users:**
- Refresh interval: 1-2 minutes
- Notifications: Enabled
- Launch at login: Enabled

**For occasional users:**
- Refresh interval: 5-10 minutes
- Notifications: Optional
- Launch at login: Optional

**For battery conservation:**
- Refresh interval: 10 minutes
- Notifications: Disabled
- Launch at login: Disabled

### Troubleshooting

**Not updating:**
- Check internet connection
- Verify API key is correct
- Click "Refresh Now"

**No notifications:**
- Enable in Preferences
- Check System Settings → Notifications
- Send test notification

**High battery usage:**
- Increase refresh interval
- Disable launch at login when not needed
- Check Activity Monitor

## Support

Need help? Check:
- [README.md](README.md) - Full documentation
- [QUICKSTART.md](QUICKSTART.md) - 5-minute setup
- [GitHub Issues](https://github.com/yourusername/claude-code-usage-widget/issues) - Report bugs

---

**Enjoy monitoring your Claude Code usage!** 🚀
