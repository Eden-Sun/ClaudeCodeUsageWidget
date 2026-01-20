import Foundation
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    private var lastNotificationPercentage: Int = 0
    private let notificationThresholds = [75, 85, 95] // Notify at these percentages
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    func checkAndNotify(usage: UsageData) {
        guard AppConfig.enableNotifications else { return }
        
        let currentPercentage = Int(usage.usagePercentage)
        
        // Find the highest threshold that has been crossed
        for threshold in notificationThresholds.sorted(by: >) {
            if currentPercentage >= threshold && lastNotificationPercentage < threshold {
                sendNotification(percentage: currentPercentage, threshold: threshold, remaining: usage.remainingRequests)
                lastNotificationPercentage = threshold
                break
            }
        }
        
        // Reset if usage drops below all thresholds
        if currentPercentage < notificationThresholds.min() ?? 0 {
            lastNotificationPercentage = 0
        }
    }
    
    private func sendNotification(percentage: Int, threshold: Int, remaining: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Claude Code Usage Alert"
        
        switch threshold {
        case 95...:
            content.body = "⚠️ Critical: \(percentage)% used! Only \(remaining) requests remaining."
            content.sound = .defaultCritical
        case 85..<95:
            content.body = "🔴 High usage: \(percentage)% used. \(remaining) requests left."
            content.sound = .default
        case 75..<85:
            content.body = "🟡 Warning: \(percentage)% used. You have \(remaining) requests remaining."
            content.sound = .default
        default:
            content.body = "\(percentage)% of your Claude Code usage limit has been reached."
            content.sound = .default
        }
        
        content.categoryIdentifier = "USAGE_ALERT"
        content.userInfo = ["percentage": percentage, "remaining": remaining]
        
        let request = UNNotificationRequest(
            identifier: "usage-\(threshold)",
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error.localizedDescription)")
            }
        }
    }
    
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Claude Code Usage Widget"
        content.body = "Notifications are working! You'll receive alerts when approaching your usage limit."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "test-notification",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        lastNotificationPercentage = 0
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        // Could open the popover or navigate to settings
        completionHandler()
    }
}
