import Foundation

struct UsageHistoryEntry: Codable {
    let timestamp: Date
    let used: Int
    let limit: Int
    let percentage: Double
    let resetDate: Date?
    
    var csvRow: String {
        let dateFormatter = ISO8601DateFormatter()
        let timestampStr = dateFormatter.string(from: timestamp)
        let resetStr = resetDate.map { dateFormatter.string(from: $0) } ?? "N/A"
        return "\(timestampStr),\(used),\(limit),\(String(format: "%.2f", percentage)),\(resetStr)"
    }
}

class UsageHistoryManager {
    static let shared = UsageHistoryManager()
    
    private let historyKey = "usage_history"
    private let maxHistoryEntries = 1000 // Keep last 1000 entries
    
    private init() {}
    
    var history: [UsageHistoryEntry] {
        get {
            guard let data = UserDefaults.standard.data(forKey: historyKey),
                  let entries = try? JSONDecoder().decode([UsageHistoryEntry].self, from: data) else {
                return []
            }
            return entries
        }
        set {
            // Keep only the most recent entries
            let limitedHistory = Array(newValue.suffix(maxHistoryEntries))
            if let data = try? JSONEncoder().encode(limitedHistory) {
                UserDefaults.standard.set(data, forKey: historyKey)
            }
        }
    }
    
    func addEntry(usage: UsageData) {
        var currentHistory = history
        
        let entry = UsageHistoryEntry(
            timestamp: Date(),
            used: usage.used,
            limit: usage.limit,
            percentage: usage.usagePercentage,
            resetDate: usage.resetDate
        )
        
        currentHistory.append(entry)
        history = currentHistory
    }
    
    func exportToCSV() -> String {
        var csv = "Timestamp,Used,Limit,Percentage,Reset Date\n"
        
        for entry in history {
            csv += entry.csvRow + "\n"
        }
        
        return csv
    }
    
    func saveCSVToFile() -> URL? {
        let csv = exportToCSV()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let filename = "claude_usage_\(dateFormatter.string(from: Date())).csv"
        
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        guard let fileURL = downloadsURL?.appendingPathComponent(filename) else {
            return nil
        }
        
        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to save CSV: \(error)")
            return nil
        }
    }
    
    func clearHistory() {
        history = []
    }
    
    func getStatistics() -> UsageStatistics? {
        guard !history.isEmpty else { return nil }
        
        let percentages = history.map { $0.percentage }
        let used = history.map { $0.used }
        
        return UsageStatistics(
            totalEntries: history.count,
            averagePercentage: percentages.reduce(0, +) / Double(percentages.count),
            maxPercentage: percentages.max() ?? 0,
            minPercentage: percentages.min() ?? 0,
            averageUsed: Double(used.reduce(0, +)) / Double(used.count),
            currentStreak: calculateCurrentStreak(),
            firstEntry: history.first?.timestamp,
            lastEntry: history.last?.timestamp
        )
    }
    
    private func calculateCurrentStreak() -> Int {
        // Calculate consecutive days with data
        guard !history.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        var streak = 1
        var currentDate = calendar.startOfDay(for: history.last!.timestamp)
        
        for entry in history.reversed().dropFirst() {
            let entryDate = calendar.startOfDay(for: entry.timestamp)
            let daysDiff = calendar.dateComponents([.day], from: entryDate, to: currentDate).day ?? 0
            
            if daysDiff == 1 {
                streak += 1
                currentDate = entryDate
            } else if daysDiff > 1 {
                break
            }
        }
        
        return streak
    }
    
    func getEntriesForLastDays(_ days: Int) -> [UsageHistoryEntry] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return history.filter { $0.timestamp >= cutoffDate }
    }
}

struct UsageStatistics {
    let totalEntries: Int
    let averagePercentage: Double
    let maxPercentage: Double
    let minPercentage: Double
    let averageUsed: Double
    let currentStreak: Int
    let firstEntry: Date?
    let lastEntry: Date?
}
