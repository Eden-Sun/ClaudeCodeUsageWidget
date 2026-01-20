# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Menu bar icon color customization
- Widget for macOS Dashboard
- Support for multiple API keys/accounts
- Siri Shortcuts integration
- iCloud sync for settings

## [1.1.0] - 2025-01-20

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
