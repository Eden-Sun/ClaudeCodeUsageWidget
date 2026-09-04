# Version 1.1.0 - What's New! 🎉

> ## ⚠️ HISTORICAL DOCUMENT — DOES NOT DESCRIBE THE CURRENT APP
>
> This file is the release note for **version 1.1.0 (January 2025)**. It is kept
> as a record of what shipped then. The app is now at **2.6**, and *none* of the
> features below still exist:
>
> - **No API key.** 1.1 asked you for an Anthropic Console key. Since 2.0 the
>   app reads the OAuth token Claude Code already stores in your login Keychain,
>   and there is no key field anywhere.
> - **No notifications**, no threshold alerts.
> - **No statistics window**, no charts, no usage history, no CSV export.
> - **No preferences window** and no refresh-interval slider. Settings has two
>   read-mostly sections: which profile the menu bar tracks, and a list of the
>   profiles Claude Code has logged in.
> - **No launch-at-login toggle.**
> - The five Swift files listed under "New Components" below —
>   `NotificationManager.swift`, `UsageHistoryManager.swift`,
>   `StatisticsView.swift`, `PreferencesView.swift`, `LaunchAtLoginHelper.swift`
>   — were deleted in 2.0, along with `UsageView.swift` and `AppConfig.swift`.
>
> For what the app actually does today, see [README.md](README.md),
> [FEATURES.md](FEATURES.md) and [CHANGELOG.md](CHANGELOG.md).

A major update to Claude Code Usage Widget with exciting new features!

## 🚀 New Features

### 1. Smart Notifications
Never run out of requests unexpectedly!
- Get alerts at 75%, 85%, and 95% usage
- Smart threshold-based notifications
- Different alert levels for different severities
- Test notification feature to verify setup

**How to use:**
- Open Preferences → Enable "Enable usage alerts"
- Grant notification permission
- Notifications appear automatically when thresholds are crossed

### 2. Usage Statistics Dashboard
Beautiful visualizations of your usage patterns!
- **Overview Cards**: Average, Peak, Total Checks, Tracking Streak
- **Interactive Chart**: Line chart with 7/14/30 day views
- **Trend Analysis**: See your usage patterns over time
- **Export to CSV**: Download your complete usage history

**How to use:**
- Right-click menu bar icon → Statistics
- Select timeframe (7, 14, or 30 days)
- Export data with one click

### 3. Comprehensive Preferences Window
All settings in one beautiful interface!
- API key management
- Update interval customization (1-10 minutes)
- Notification settings
- Launch at login toggle
- Data management options

**How to use:**
- Right-click menu bar icon → Preferences
- Or press ⌘, (Command-Comma)

### 4. Launch at Login
Start automatically with macOS!
- Native macOS integration
- Uses SMAppService (macOS 13+)
- One-click enable/disable
- Shows current status

**How to use:**
- Open Preferences → Toggle "Launch at login"

### 5. Right-Click Menu
Quick access to all features!
- Open Usage
- Statistics
- Preferences
- Refresh Now
- Quit

**How to use:**
- Right-click the menu bar icon

### 6. Usage History Tracking
Automatic logging of all usage checks!
- Stores up to 1000 entries
- Tracks timestamp, usage, limit, percentage
- Exports to CSV format
- Used for statistics and trends

### 7. Secure Keychain Storage
Enhanced security for your API key!
- Stores keys in macOS Keychain
- Auto-migrates from UserDefaults
- Encrypted at rest
- Easy removal

## 🎨 Improvements

### Simplified Main Popover
- Cleaner interface
- Removed inline settings (moved to Preferences)
- Focus on usage display
- Faster load times

### Better Code Organization
- **NotificationManager**: Handles all notification logic
- **UsageHistoryManager**: Manages data tracking and export
- **LaunchAtLoginHelper**: System integration
- **PreferencesView**: Dedicated settings interface
- **StatisticsView**: Beautiful analytics dashboard

### Enhanced User Experience
- More intuitive navigation
- Better visual feedback
- Clearer error messages
- Improved performance

## 📊 Technical Improvements

### New Components
```
NotificationManager.swift       - Smart notification system
UsageHistoryManager.swift      - Data tracking and export
StatisticsView.swift           - Analytics dashboard
PreferencesView.swift          - Settings interface
LaunchAtLoginHelper.swift      - Auto-start functionality
```

### Updated Components
```
ClaudeCodeUsageApp.swift       - Right-click menu, window management
UsageView.swift                - Simplified interface
UsageMonitor.swift             - Integrated notifications & history
AppConfig.swift                - Added notification settings
```

### Frameworks Used
- **UserNotifications**: For smart alerts
- **Charts**: For beautiful visualizations
- **ServiceManagement**: For launch at login
- **Security**: For Keychain integration

## 🎯 Quick Start with v1.1

1. **Update to v1.1**
   - Download and build the new version
   - Your API key will be automatically migrated to Keychain

2. **Enable Notifications**
   - Open Preferences (⌘,)
   - Toggle "Enable usage alerts"
   - Grant notification permission
   - Send a test notification

3. **Set Launch at Login**
   - Open Preferences
   - Toggle "Launch at login"
   - App starts automatically with macOS

4. **Explore Statistics**
   - Right-click menu bar → Statistics
   - View your usage trends
   - Export data to CSV

5. **Customize Update Interval**
   - Open Preferences
   - Adjust refresh interval slider (1-10 min)
   - Save automatically

## 📈 Statistics Features

### Overview Cards
- **Average Usage**: Your typical usage percentage
- **Peak Usage**: Highest usage reached
- **Total Checks**: Number of API calls made
- **Tracking Streak**: Consecutive days with data

### Interactive Chart
- Line chart with gradient fill
- Smooth curve interpolation
- Auto-formatted dates
- Select 7, 14, or 30 day view

### Data Export
- One-click CSV export
- Saved to Downloads folder
- Open in Excel, Numbers, Google Sheets
- Complete history included

## 🔔 Notification System

### Threshold Levels
| Usage | Alert Level | Icon | Sound |
|-------|------------|------|-------|
| 75% | Warning | 🟡 | Default |
| 85% | High | 🔴 | Default |
| 95% | Critical | ⚠️ | Critical |

### Smart Features
- Only notifies when crossing threshold UP
- Won't spam with repeated alerts
- Resets when usage drops
- Includes remaining request count

## 🎨 User Interface

### Menu Bar
- Color-coded indicator (●/⚠️)
- Usage percentage display
- Left-click: Open popover
- Right-click: Quick menu

### Popover (Left-Click)
- Circular progress indicator
- Detailed statistics
- Refresh button
- Clean, focused design

### Right-Click Menu
- Open Usage
- Statistics
- Preferences
- Refresh Now
- Quit

### Preferences Window
- API Configuration
- Update Settings
- Notifications
- Startup Options
- Data Management
- About Section

### Statistics Window
- Overview cards
- Interactive chart
- Timeframe selector
- Export button

## 🔒 Security & Privacy

### Enhanced Security
- API keys in macOS Keychain
- Encrypted storage
- Secure migration from UserDefaults
- Easy key removal

### Privacy Features
- All data stored locally
- No cloud sync (yet)
- No third-party tracking
- You control your data

### Data Management
- Clear all data option
- Remove API key
- Reset preferences
- Clear history

## 📚 Documentation

### New Documentation
- **FEATURES.md**: Complete feature guide
- **VERSION_1.1_SUMMARY.md**: This file!

### Updated Documentation
- **README.md**: Updated with new features
- **CHANGELOG.md**: Version history
- **QUICKSTART.md**: Updated setup guide
- **OVERVIEW.md**: Updated project structure

## 🚀 What's Next

### Planned Features
- Menu bar icon color customization
- macOS Dashboard widget
- Multiple API keys/accounts
- Siri Shortcuts integration
- iCloud sync for settings
- Advanced analytics
- Team usage tracking

### Community
- Report bugs on GitHub Issues
- Request features
- Contribute code
- Share feedback

## 💡 Tips for Best Experience

### For Power Users
```
✓ Refresh interval: 1-2 minutes
✓ Notifications: Enabled
✓ Launch at login: Enabled
✓ Export data weekly
```

### For Casual Users
```
✓ Refresh interval: 5-10 minutes
✓ Notifications: Optional
✓ Launch at login: Optional
✓ Check statistics monthly
```

### For Battery Life
```
✓ Refresh interval: 10 minutes
✓ Notifications: Disabled (or only critical)
✓ Launch at login: Disabled when not needed
```

## 🎉 Enjoy!

We hope you love these new features! The app is now more powerful, more beautiful, and more useful than ever.

**Feedback?** Let us know what you think!

**Issues?** Report them on GitHub.

**Ideas?** We'd love to hear them!

---

**Version 1.1.0** - Built with ❤️ for the Claude Code community
