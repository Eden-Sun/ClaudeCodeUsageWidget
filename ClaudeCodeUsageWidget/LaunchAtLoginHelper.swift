import Foundation
import ServiceManagement

class LaunchAtLoginHelper {
    static let shared = LaunchAtLoginHelper()
    
    private let launchAtLoginKey = "launch_at_login"
    
    private init() {}
    
    var isEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: launchAtLoginKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: launchAtLoginKey)
            updateLaunchAgent(enabled: newValue)
        }
    }
    
    private func updateLaunchAgent(enabled: Bool) {
        if #available(macOS 13.0, *) {
            // For macOS 13+, use SMAppService
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            }
        } else {
            // For older macOS versions, use the legacy API
            #if compiler(>=5.9)
            SMLoginItemSetEnabled("com.claudecode.usagewidget.launcher" as CFString, enabled)
            #endif
        }
    }
    
    func checkStatus() -> String {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            switch status {
            case .enabled:
                return "Enabled"
            case .notRegistered:
                return "Not Registered"
            case .notFound:
                return "Not Found"
            case .requiresApproval:
                return "Requires Approval"
            @unknown default:
                return "Unknown"
            }
        } else {
            return isEnabled ? "Enabled (Legacy)" : "Disabled"
        }
    }
}
