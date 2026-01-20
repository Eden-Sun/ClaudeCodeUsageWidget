import Foundation

enum AppConfig {
    // MARK: - API Configuration
    
    /// Base URL for the Claude API
    static let apiBaseURL = "https://api.anthropic.com/v1"
    
    /// API endpoint for usage information
    static let usageEndpoint = "\(apiBaseURL)/usage"
    
    /// API version header
    static let apiVersion = "2023-06-01"
    
    // MARK: - Update Configuration
    
    /// How often to fetch usage data (in seconds)
    /// Default: 300 seconds (5 minutes)
    /// Recommended range: 60-600 seconds
    static let updateInterval: TimeInterval = 300
    
    /// Enable/disable automatic background updates
    static let enableAutoRefresh = true
    
    // MARK: - Notification Configuration
    
    /// Enable/disable usage notifications
    static let enableNotifications = true
    
    /// Notification thresholds (percentage)
    static let notificationThresholds = [75, 85, 95]
    
    // MARK: - UI Configuration
    
    /// Width of the popover window
    static let popoverWidth: CGFloat = 300
    
    /// Height of the popover window
    static let popoverHeight: CGFloat = 400
    
    /// Size of the circular progress indicator
    static let progressCircleSize: CGFloat = 150
    
    /// Line width for the progress circle
    static let progressLineWidth: CGFloat = 20
    
    // MARK: - Usage Thresholds
    
    /// Color thresholds for usage percentage
    struct UsageThresholds {
        static let green: ClosedRange<Double> = 0...24
        static let yellow: ClosedRange<Double> = 25...49
        static let orange: ClosedRange<Double> = 50...74
        static let red: ClosedRange<Double> = 75...89
        static let critical: ClosedRange<Double> = 90...100
    }
    
    // MARK: - Storage
    
    /// Keychain service identifier
    static let keychainService = "com.claudecode.usagewidget"
    
    /// Keychain account identifier for API key
    static let keychainAccount = "claude_api_key"
    
    // MARK: - Debug
    
    /// Enable debug mode (uses mock data when API fails)
    static let debugMode = false
    
    /// Mock usage data for testing
    struct MockData {
        static let used = 450
        static let limit = 1000
        static let resetHours = 24
    }
    
    // MARK: - Display Format
    
    /// Show percentage in menu bar
    static let showPercentageInMenuBar = true
    
    /// Show icon indicator in menu bar
    static let showIconInMenuBar = true
    
    /// Date format for reset time
    static let dateFormatStyle = "relative" // "relative" or "absolute"
}
