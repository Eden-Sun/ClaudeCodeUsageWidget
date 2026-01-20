import SwiftUI

struct PreferencesView: View {
    @Environment(\.dismiss) var dismiss
    @State private var apiKey = KeychainHelper.shared.getAPIKey() ?? ""
    @State private var launchAtLogin = LaunchAtLoginHelper.shared.isEnabled
    @State private var enableNotifications = UserDefaults.standard.bool(forKey: "enable_notifications")
    @State private var updateInterval = UserDefaults.standard.double(forKey: "update_interval")
    @State private var showingTestNotification = false
    @State private var showingClearDataAlert = false
    
    init() {
        // Set default update interval if not set
        let savedInterval = UserDefaults.standard.double(forKey: "update_interval")
        _updateInterval = State(initialValue: savedInterval > 0 ? savedInterval : AppConfig.updateInterval)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Preferences")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Done") {
                    saveAndClose()
                }
                .keyboardShortcut(.return)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // API Configuration Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("API Configuration", systemImage: "key.fill")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API Key")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            SecureField("sk-ant-...", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                            
                            Text("Get your API key from the Anthropic Console")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Button("Open Anthropic Console") {
                                    if let url = URL(string: "https://console.anthropic.com") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .buttonStyle(.link)
                                .font(.caption)
                                
                                Spacer()
                                
                                if !apiKey.isEmpty {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Update Settings Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Update Settings", systemImage: "arrow.clockwise")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Refresh Interval")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(Int(updateInterval / 60)) min")
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $updateInterval, in: 60...600, step: 60)
                            
                            HStack {
                                Text("1 min")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("10 min")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("How often to check usage (lower = more API calls)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Notifications Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Notifications", systemImage: "bell.fill")
                            .font(.headline)
                        
                        Toggle("Enable usage alerts", isOn: $enableNotifications)
                            .onChange(of: enableNotifications) { newValue in
                                if newValue {
                                    NotificationManager.shared.requestAuthorization()
                                }
                            }
                        
                        if enableNotifications {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("You'll receive notifications at:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Image(systemName: "bell.badge")
                                        .foregroundColor(.yellow)
                                    Text("75% usage")
                                        .font(.caption)
                                }
                                
                                HStack {
                                    Image(systemName: "bell.badge.fill")
                                        .foregroundColor(.orange)
                                    Text("85% usage")
                                        .font(.caption)
                                }
                                
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text("95% usage (Critical)")
                                        .font(.caption)
                                }
                                
                                Button("Send Test Notification") {
                                    NotificationManager.shared.sendTestNotification()
                                    showingTestNotification = true
                                }
                                .buttonStyle(.bordered)
                                .padding(.top, 4)
                            }
                            .padding(.leading)
                        }
                    }
                    
                    Divider()
                    
                    // Startup Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Startup", systemImage: "power")
                            .font(.headline)
                        
                        Toggle("Launch at login", isOn: $launchAtLogin)
                            .onChange(of: launchAtLogin) { newValue in
                                LaunchAtLoginHelper.shared.isEnabled = newValue
                            }
                        
                        Text("Start automatically when you log in to macOS")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Status: \(LaunchAtLoginHelper.shared.checkStatus())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Data Management Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Data Management", systemImage: "externaldrive")
                            .font(.headline)
                        
                        Button(role: .destructive) {
                            showingClearDataAlert = true
                        } label: {
                            Label("Clear All Data", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        
                        Text("Remove API key and reset all settings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // About Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("About", systemImage: "info.circle")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Claude Code Usage Widget")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text("Version 1.0.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Built with Swift & AppKit")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 12) {
                            Button("GitHub") {
                                if let url = URL(string: "https://github.com/yourusername/claude-code-usage-widget") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.link)
                            
                            Button("Report Issue") {
                                if let url = URL(string: "https://github.com/yourusername/claude-code-usage-widget/issues") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.link)
                        }
                        .font(.caption)
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
        .alert("Clear All Data?", isPresented: $showingClearDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This will remove your API key and reset all settings. This action cannot be undone.")
        }
        .alert("Test Notification Sent", isPresented: $showingTestNotification) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Check your notification center to see if notifications are working.")
        }
    }
    
    private func saveAndClose() {
        // Save API key
        if !apiKey.isEmpty {
            _ = KeychainHelper.shared.saveAPIKey(apiKey)
        }
        
        // Save preferences
        UserDefaults.standard.set(enableNotifications, forKey: "enable_notifications")
        UserDefaults.standard.set(updateInterval, forKey: "update_interval")
        
        // Notify that settings changed
        NotificationCenter.default.post(name: NSNotification.Name("PreferencesDidChange"), object: nil)
        
        dismiss()
    }
    
    private func clearAllData() {
        // Remove API key
        _ = KeychainHelper.shared.deleteAPIKey()
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "enable_notifications")
        UserDefaults.standard.removeObject(forKey: "update_interval")
        UserDefaults.standard.removeObject(forKey: "launch_at_login")
        
        // Disable launch at login
        LaunchAtLoginHelper.shared.isEnabled = false
        
        // Clear notifications
        NotificationManager.shared.clearAllNotifications()
        
        // Reset UI
        apiKey = ""
        launchAtLogin = false
        enableNotifications = false
        updateInterval = AppConfig.updateInterval
        
        dismiss()
    }
}

#Preview {
    PreferencesView()
}
