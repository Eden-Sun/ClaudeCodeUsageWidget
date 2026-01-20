import Cocoa
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var usageMonitor: UsageMonitor!
    var preferencesWindow: NSWindow?
    var statisticsWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Migrate API key from UserDefaults to Keychain if needed
        KeychainHelper.shared.migrateFromUserDefaults()
        
        // Request notification permissions
        NotificationManager.shared.requestAuthorization()
        
        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.title = "..."
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Create the menu for right-click
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Open Usage", action: #selector(togglePopover), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Statistics", action: #selector(showStatistics), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        // Create the popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: AppConfig.popoverWidth, height: AppConfig.popoverHeight)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: UsageView())
        
        // Initialize usage monitor
        usageMonitor = UsageMonitor()
        usageMonitor.onUsageUpdate = { [weak self] usage in
            self?.updateStatusBar(with: usage)
        }
        
        // Start monitoring
        usageMonitor.startMonitoring()
    }
    
    @objc func togglePopover() {
        // Check if this was a right-click
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showMenu()
            return
        }
        
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
    
    @objc func showMenu() {
        if let button = statusItem.button, let menu = NSMenu() as NSMenu? {
            menu.addItem(NSMenuItem(title: "Open Usage", action: #selector(openPopover), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Statistics", action: #selector(showStatistics), keyEquivalent: "s"))
            menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
            
            statusItem.menu = menu
            button.performClick(nil)
            statusItem.menu = nil
        }
    }
    
    @objc func openPopover() {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    @objc func showPreferences() {
        if preferencesWindow == nil {
            let preferencesView = PreferencesView()
            let hostingController = NSHostingController(rootView: preferencesView)
            
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Preferences"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            
            preferencesWindow = window
        }
        
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func showStatistics() {
        if statisticsWindow == nil {
            let statisticsView = StatisticsView()
            let hostingController = NSHostingController(rootView: statisticsView)
            
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Usage Statistics"
            window.styleMask = [.titled, .closable, .resizable]
            window.setContentSize(NSSize(width: 500, height: 600))
            window.isReleasedWhenClosed = false
            window.center()
            
            statisticsWindow = window
        }
        
        statisticsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func refreshNow() {
        usageMonitor.fetchUsage()
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    func updateStatusBar(with usage: UsageData) {
        if let button = statusItem.button {
            let percentage = usage.usagePercentage
            let icon = getIconForUsage(percentage)
            button.title = "\(icon) \(Int(percentage))%"
        }
    }
    
    func getIconForUsage(_ percentage: Double) -> String {
        switch percentage {
        case AppConfig.UsageThresholds.green:
            return "●" // Green zone
        case AppConfig.UsageThresholds.yellow:
            return "●" // Yellow zone
        case AppConfig.UsageThresholds.orange:
            return "●" // Orange zone
        case AppConfig.UsageThresholds.red:
            return "●" // Red zone
        default:
            return "⚠️" // Critical zone
        }
    }
}
