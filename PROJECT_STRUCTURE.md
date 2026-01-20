# Project Structure

Complete overview of the Claude Code Usage Widget project structure and file organization.

## Directory Tree

```
ClaudeCodeUsageWidget/
├── ClaudeCodeUsageWidget/              # Main app source code
│   ├── ClaudeCodeUsageApp.swift        # App entry point & menu bar
│   ├── UsageMonitor.swift              # API integration & polling
│   ├── UsageView.swift                 # Main popover view
│   ├── PreferencesView.swift           # Settings window
│   ├── StatisticsView.swift            # Analytics dashboard
│   ├── NotificationManager.swift       # Smart notifications
│   ├── UsageHistoryManager.swift       # Data tracking & export
│   ├── KeychainHelper.swift            # Secure storage
│   ├── LaunchAtLoginHelper.swift       # Auto-start functionality
│   ├── AppConfig.swift                 # Centralized configuration
│   └── Info.plist                      # App metadata
├── ClaudeCodeUsageWidget.xcodeproj/    # Xcode project
│   └── project.pbxproj                 # Project configuration
├── README.md                           # Main documentation
├── QUICKSTART.md                       # 5-minute setup guide
├── FEATURES.md                         # Complete features guide
├── OVERVIEW.md                         # Project overview
├── CHANGELOG.md                        # Version history
├── VERSION_1.1_SUMMARY.md              # v1.1 highlights
├── PROJECT_STRUCTURE.md                # This file
├── LICENSE                             # MIT License
└── .gitignore                          # Git ignore rules
```

## Core Files

### ClaudeCodeUsageApp.swift
**Purpose**: Main application entry point and AppKit integration

**Key Responsibilities**:
- Creates and manages menu bar status item
- Handles left-click (popover) and right-click (menu)
- Manages preferences and statistics windows
- Updates menu bar icon with usage data
- Color-coded indicator system

**Key Components**:
- `AppDelegate`: Main app class
- `applicationDidFinishLaunching()`: Setup method
- `togglePopover()`: Show/hide main view
- `showMenu()`: Display right-click menu
- `showPreferences()`: Open settings window
- `showStatistics()`: Open analytics window
- `updateStatusBar()`: Update menu bar display
- `getIconForUsage()`: Color indicator logic

**Dependencies**:
- UsageMonitor
- PreferencesView
- StatisticsView
- NotificationManager
- KeychainHelper

### UsageMonitor.swift
**Purpose**: API communication and data fetching

**Key Responsibilities**:
- Fetches usage data from Claude API
- Background polling at configured interval
- Error handling and retry logic
- Mock data support for testing
- Notifies subscribers of updates

**Key Components**:
- `UsageMonitor`: ObservableObject class
- `UsageData`: Data model
- `fetchUsage()`: API call method
- `startMonitoring()`: Begin polling
- `stopMonitoring()`: End polling
- `APIUsageResponse`: API response model

**Dependencies**:
- AppConfig
- KeychainHelper
- NotificationManager
- UsageHistoryManager

### UsageView.swift
**Purpose**: Main popover user interface

**Key Responsibilities**:
- Displays circular progress indicator
- Shows detailed usage statistics
- Manual refresh capability
- Error display with retry
- Loading states

**Key Components**:
- `UsageView`: Main SwiftUI view
- Circular progress display
- Usage detail rows
- Refresh button
- Error handling UI
- `DetailRow`: Reusable stat display
- `colorForUsage()`: Color mapping

**Dependencies**:
- UsageMonitor
- AppConfig

### PreferencesView.swift
**Purpose**: Comprehensive settings interface

**Key Responsibilities**:
- API key configuration
- Update interval adjustment
- Notification settings
- Launch at login toggle
- Data management
- About section

**Key Components**:
- `PreferencesView`: Main settings view
- API configuration section
- Update settings with slider
- Notification toggles
- Startup options
- Data clearing functionality
- `saveAndClose()`: Save preferences
- `clearAllData()`: Reset everything

**Dependencies**:
- KeychainHelper
- LaunchAtLoginHelper
- NotificationManager
- AppConfig

### StatisticsView.swift
**Purpose**: Usage analytics and visualization

**Key Responsibilities**:
- Displays usage statistics
- Interactive charts
- Timeframe selection (7/14/30 days)
- CSV export functionality
- Overview cards

**Key Components**:
- `StatisticsView`: Main analytics view
- Overview stat cards
- Line chart with Charts framework
- Timeframe selector
- Export button
- `StatCard`: Reusable card view
- `loadData()`: Fetch statistics
- `exportData()`: Generate CSV

**Dependencies**:
- UsageHistoryManager
- Charts framework

### NotificationManager.swift
**Purpose**: Smart notification system

**Key Responsibilities**:
- Manages notification permissions
- Threshold-based alerts
- Prevents duplicate notifications
- Different alert levels
- Test notifications

**Key Components**:
- `NotificationManager`: Singleton class
- `requestAuthorization()`: Ask for permission
- `checkAndNotify()`: Threshold checking
- `sendNotification()`: Create alert
- `sendTestNotification()`: Test functionality
- `clearAllNotifications()`: Reset state

**Configuration**:
- Thresholds: 75%, 85%, 95%
- Alert levels: Warning, High, Critical
- Sounds: Default and Critical

### UsageHistoryManager.swift
**Purpose**: Data tracking and export

**Key Responsibilities**:
- Logs all usage checks
- Stores up to 1000 entries
- Generates statistics
- Exports to CSV
- Calculates streaks

**Key Components**:
- `UsageHistoryManager`: Singleton class
- `UsageHistoryEntry`: Data model
- `addEntry()`: Log new check
- `exportToCSV()`: Generate CSV
- `saveCSVToFile()`: Write to disk
- `getStatistics()`: Calculate stats
- `getEntriesForLastDays()`: Filter by date
- `UsageStatistics`: Stats model

**Storage**:
- UserDefaults for persistence
- JSON encoding/decoding
- Max 1000 entries

### KeychainHelper.swift
**Purpose**: Secure credential storage

**Key Responsibilities**:
- Saves API key to Keychain
- Retrieves API key securely
- Deletes API key
- Migrates from UserDefaults

**Key Components**:
- `KeychainHelper`: Singleton class
- `saveAPIKey()`: Store key
- `getAPIKey()`: Retrieve key
- `deleteAPIKey()`: Remove key
- `hasAPIKey()`: Check existence
- `migrateFromUserDefaults()`: Legacy migration

**Security**:
- macOS Keychain integration
- Encrypted storage
- `kSecAttrAccessibleAfterFirstUnlock`

### LaunchAtLoginHelper.swift
**Purpose**: Auto-start functionality

**Key Responsibilities**:
- Enables/disables launch at login
- macOS system integration
- Status checking

**Key Components**:
- `LaunchAtLoginHelper`: Singleton class
- `isEnabled`: Get/set launch status
- `updateLaunchAgent()`: System integration
- `checkStatus()`: Get current state

**Platform Support**:
- macOS 13+: SMAppService
- Older macOS: Legacy API

### AppConfig.swift
**Purpose**: Centralized configuration

**Key Responsibilities**:
- API settings
- Update intervals
- UI dimensions
- Usage thresholds
- Debug mode
- Notification settings

**Key Sections**:
```swift
// API Configuration
apiBaseURL, usageEndpoint, apiVersion

// Update Configuration
updateInterval, enableAutoRefresh

// Notification Configuration
enableNotifications, notificationThresholds

// UI Configuration
popoverWidth, popoverHeight, progressCircleSize

// Usage Thresholds
UsageThresholds.green/yellow/orange/red/critical

// Storage
keychainService, keychainAccount

// Debug
debugMode, MockData
```

### Info.plist
**Purpose**: App metadata and configuration

**Key Settings**:
- Bundle identifier
- Version information
- LSUIElement: true (menu bar app)
- Network security settings
- macOS version requirements

## Documentation Files

### README.md
Complete documentation including:
- Features overview
- Installation instructions
- Configuration guide
- Usage examples
- Troubleshooting
- Contributing guidelines

### QUICKSTART.md
5-minute setup guide:
- Prerequisites
- Step-by-step setup
- API key configuration
- First usage
- Quick tips

### FEATURES.md
Comprehensive feature guide:
- Basic features
- Advanced features
- Preferences detailed
- Statistics explained
- Notification system
- Tips & tricks

### OVERVIEW.md
Project overview:
- Architecture explanation
- File purposes
- Quick configuration
- Getting started
- Common tasks

### CHANGELOG.md
Version history:
- All releases
- Features added
- Improvements made
- Bug fixes
- Technical changes

### VERSION_1.1_SUMMARY.md
v1.1 highlights:
- New features overview
- Improvements
- Quick start guide
- What's next

### LICENSE
MIT License terms

## Build Configuration

### Xcode Project
- Target: macOS 13.0+
- Language: Swift 5.9
- Frameworks: AppKit, SwiftUI, Charts, UserNotifications
- Bundle ID: com.claudecode.usagewidget

### Build Settings
- Code signing
- Deployment target
- Swift optimization
- Asset catalog

## Data Flow

```
User → Menu Bar Click
    ↓
    → Left Click → UsageView
    |   ↓
    |   → UsageMonitor → API Request
    |       ↓
    |       → Update UI
    |       → NotificationManager
    |       → UsageHistoryManager
    |
    → Right Click → Menu
        ↓
        → Preferences → PreferencesView
        |   ↓
        |   → KeychainHelper
        |   → LaunchAtLoginHelper
        |
        → Statistics → StatisticsView
            ↓
            → UsageHistoryManager
            → Export CSV
```

## Key Design Patterns

### Singleton Pattern
- NotificationManager
- UsageHistoryManager
- KeychainHelper
- LaunchAtLoginHelper

### Observer Pattern
- UsageMonitor (ObservableObject)
- SwiftUI state management
- NotificationCenter for settings changes

### Delegate Pattern
- NSApplicationDelegate (AppDelegate)
- UNUserNotificationCenterDelegate

### MVC/MVVM Hybrid
- Models: UsageData, UsageHistoryEntry
- Views: SwiftUI views
- ViewModels: UsageMonitor (observable)
- Controllers: AppDelegate

## Testing Considerations

### Debug Mode
- AppConfig.debugMode
- Mock data support
- Test notifications
- Local development

### Manual Testing
- API integration
- Notification flow
- Keychain operations
- UI interactions

## Performance

### Optimization
- Efficient polling
- Minimal API calls
- Background thread operations
- SwiftUI optimizations

### Resource Usage
- Low CPU usage
- Minimal memory footprint
- Efficient network calls
- Smart caching

## Future Expansion

### Planned Files
- WidgetExtension.swift (Dashboard widget)
- CloudSyncManager.swift (iCloud sync)
- MultiAccountManager.swift (Multiple accounts)
- SiriIntents.swift (Shortcuts)

### Modular Design
- Easy to add features
- Clean separation of concerns
- Reusable components
- Testable architecture

---

**Total Files**: 20
**Lines of Code**: ~2500+
**Languages**: Swift, XML
**Frameworks**: 7+
