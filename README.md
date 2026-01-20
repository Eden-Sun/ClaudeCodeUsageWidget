# Claude Code Usage Widget for macOS

A native macOS menu bar app that displays your Claude Code API usage in real-time. Built with Swift and AppKit for optimal performance and native macOS integration.

![Claude Code Usage Widget](screenshot.png)

## Features

- **Menu Bar Integration**: Always visible usage percentage in your macOS menu bar
- **Real-time Monitoring**: Auto-refreshes usage data every 5 minutes (customizable)
- **Visual Indicators**: Color-coded usage levels (green → yellow → orange → red → critical)
- **Detailed Popover**: Click to see detailed usage statistics
- **Circular Progress**: Beautiful circular progress indicator showing usage percentage
- **Usage Breakdown**: Shows used, remaining, and total limit
- **Reset Timer**: Displays when your usage will reset
- **Smart Notifications**: Get alerts at 75%, 85%, and 95% usage
- **Usage Statistics**: Track usage trends over time with beautiful charts
- **Data Export**: Export usage history to CSV for analysis
- **Launch at Login**: Automatically start with macOS
- **Secure API Key Storage**: Uses macOS Keychain for secure credential storage
- **Comprehensive Preferences**: Easy-to-use preferences window
- **Right-Click Menu**: Quick access to all features
- **Low Resource Usage**: Native Swift app with minimal CPU and memory footprint

## Screenshots

### Menu Bar Display
The widget shows current usage percentage directly in your menu bar with a color-coded indicator.

### Popover Details
Click the menu bar icon to see:
- Large circular progress indicator
- Used requests count
- Remaining requests
- Total limit
- Time until reset

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (for building)
- Claude API key (get from [Anthropic Console](https://console.anthropic.com))

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

4. **Configure API Key**
   - Click the menu bar icon
   - Click the gear icon (⚙️) in the popover
   - Enter your Claude API key
   - Click "Save"

### Option 2: Download Pre-built App (Coming Soon)

Download the latest `.dmg` file from the [Releases](https://github.com/yourusername/claude-code-usage-widget/releases) page.

## Configuration

### Getting Your API Key

1. Go to [Anthropic Console](https://console.anthropic.com)
2. Sign in or create an account
3. Navigate to API Keys section
4. Create a new API key
5. Copy the key and paste it into the widget settings

### Customizing Update Interval

By default, the app checks usage every 5 minutes. To change this:

1. Open `UsageMonitor.swift`
2. Find the line: `private let updateInterval: TimeInterval = 300`
3. Change `300` to your desired interval in seconds
4. Rebuild the app

## Usage Indicators

The menu bar icon changes color based on your usage:

- **● Green** (0-24%): Plenty of requests remaining
- **● Yellow** (25-49%): About half used
- **● Orange** (50-74%): Getting close to limit
- **● Red** (75-89%): Nearly at limit
- **⚠️ Critical** (90-100%): At or near limit

## How It Works

1. **Status Bar Item**: Creates a menu bar item showing current usage percentage
2. **Background Monitoring**: Polls the Claude API every 5 minutes
3. **Data Parsing**: Processes API response and calculates usage percentage
4. **Visual Update**: Updates menu bar icon and popover with latest data
5. **Secure Storage**: API key stored securely in UserDefaults (consider Keychain for production)

## API Integration

The app connects to the Anthropic API to fetch usage data. The current implementation uses:

```
Endpoint: https://api.anthropic.com/v1/usage
Method: GET
Headers:
  - x-api-key: YOUR_API_KEY
  - Content-Type: application/json
  - anthropic-version: 2023-06-01
```

**Note**: The actual Claude Code API endpoint may differ. Update the URL in `UsageMonitor.swift` if needed.

## Development

### Project Structure

```
ClaudeCodeUsageWidget/
├── ClaudeCodeUsageWidget/
│   ├── ClaudeCodeUsageApp.swift    # Main app and status bar setup
│   ├── UsageMonitor.swift          # API integration and data fetching
│   ├── UsageView.swift             # SwiftUI popover interface
│   └── Info.plist                  # App configuration
├── ClaudeCodeUsageWidget.xcodeproj/
└── README.md
```

### Key Components

**ClaudeCodeUsageApp.swift**
- App entry point and lifecycle management
- Status bar item creation
- Popover management
- Usage percentage display logic

**UsageMonitor.swift**
- API communication
- Usage data model
- Background polling
- Error handling

**UsageView.swift**
- SwiftUI interface for popover
- Circular progress indicator
- Settings panel
- Usage statistics display

### Building for Distribution

1. **Archive the app**
   - In Xcode: `Product > Archive`
   
2. **Notarize (for distribution outside App Store)**
   - Sign with your Developer ID
   - Submit for notarization
   - Staple the notarization ticket

3. **Create DMG**
   - Use `create-dmg` or similar tool
   - Include installation instructions

## Troubleshooting

### "API key not set" error
- Make sure you've entered your API key in settings
- Verify the API key is correct (check Anthropic Console)

### No data showing
- Check your internet connection
- Verify the API endpoint is correct
- Check if your API key has the necessary permissions

### Widget not appearing in menu bar
- Make sure `LSUIElement` is set to `true` in Info.plist
- Restart the app

### High CPU usage
- Increase the `updateInterval` to poll less frequently
- Check for network issues causing repeated failed requests

## Future Enhancements

- [ ] Menu bar icon color customization
- [ ] Widget for macOS Dashboard
- [ ] Support for multiple API keys/accounts
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
- Only stores your API key locally on your Mac
- Communicates directly with Anthropic's API
- Does not collect or transmit any other data
- Does not include analytics or tracking

---

**Note**: This is an unofficial app and is not affiliated with Anthropic. Use at your own discretion.
