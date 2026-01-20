import Foundation

struct UsageData: Codable {
    let used: Int
    let limit: Int
    let resetDate: Date?
    
    var usagePercentage: Double {
        guard limit > 0 else { return 0 }
        return (Double(used) / Double(limit)) * 100.0
    }
    
    var remainingRequests: Int {
        return max(0, limit - used)
    }
}

class UsageMonitor: ObservableObject {
    @Published var currentUsage: UsageData?
    @Published var isLoading = false
    @Published var error: String?
    
    var onUsageUpdate: ((UsageData) -> Void)?
    private var timer: Timer?
    private let updateInterval: TimeInterval = AppConfig.updateInterval
    
    private var apiKey: String? {
        return KeychainHelper.shared.getAPIKey()
    }
    
    func startMonitoring() {
        // Fetch immediately
        fetchUsage()
        
        // Then fetch periodically
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.fetchUsage()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func fetchUsage() {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            self.error = "API key not set"
            return
        }
        
        isLoading = true
        error = nil
        
        // Use configured API endpoint
        let url = URL(string: AppConfig.usageEndpoint)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.apiVersion, forHTTPHeaderField: "anthropic-version")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self?.error = "No data received"
                    return
                }
                
                // Try to parse the response
                do {
                    // This is a mock structure - adjust based on actual API response
                    let response = try JSONDecoder().decode(APIUsageResponse.self, from: data)
                    let usage = UsageData(
                        used: response.usage.requests_used,
                        limit: response.usage.requests_limit,
                        resetDate: ISO8601DateFormatter().date(from: response.usage.reset_date ?? "")
                    )
                    
                    self?.currentUsage = usage
                    self?.onUsageUpdate?(usage)
                    
                    // Track history
                    UsageHistoryManager.shared.addEntry(usage: usage)
                    
                    // Check for notifications
                    NotificationManager.shared.checkAndNotify(usage: usage)
                } catch {
                    self?.error = "Failed to parse response: \(error.localizedDescription)"
                    
                    // For development/testing: create mock data if debug mode enabled
                    if AppConfig.debugMode {
                        let mockUsage = UsageData(
                            used: AppConfig.MockData.used,
                            limit: AppConfig.MockData.limit,
                            resetDate: Date().addingTimeInterval(TimeInterval(AppConfig.MockData.resetHours * 3600))
                        )
                        self?.currentUsage = mockUsage
                        self?.onUsageUpdate?(mockUsage)
                    }
                }
            }
        }.resume()
    }
}

// API Response structures - adjust based on actual Claude Code API
struct APIUsageResponse: Codable {
    let usage: UsageDetails
}

struct UsageDetails: Codable {
    let requests_used: Int
    let requests_limit: Int
    let reset_date: String?
}
