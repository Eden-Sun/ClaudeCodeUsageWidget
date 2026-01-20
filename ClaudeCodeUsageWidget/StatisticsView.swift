import SwiftUI
import Charts

struct StatisticsView: View {
    @State private var statistics: UsageStatistics?
    @State private var recentHistory: [UsageHistoryEntry] = []
    @State private var selectedDays = 7
    @State private var showingExportSuccess = false
    @State private var exportedFileURL: URL?
    
    let daysOptions = [7, 14, 30]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Usage Statistics")
                    .font(.headline)
                Spacer()
                Menu {
                    ForEach(daysOptions, id: \.self) { days in
                        Button("\(days) days") {
                            selectedDays = days
                            loadData()
                        }
                    }
                } label: {
                    HStack {
                        Text("Last \(selectedDays) days")
                            .font(.caption)
                        Image(systemName: "chevron.down")
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    if let stats = statistics {
                        // Overview Cards
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            StatCard(
                                title: "Average Usage",
                                value: "\(Int(stats.averagePercentage))%",
                                icon: "chart.bar.fill",
                                color: .blue
                            )
                            
                            StatCard(
                                title: "Peak Usage",
                                value: "\(Int(stats.maxPercentage))%",
                                icon: "arrow.up.circle.fill",
                                color: .red
                            )
                            
                            StatCard(
                                title: "Total Checks",
                                value: "\(stats.totalEntries)",
                                icon: "checkmark.circle.fill",
                                color: .green
                            )
                            
                            StatCard(
                                title: "Tracking Streak",
                                value: "\(stats.currentStreak) days",
                                icon: "flame.fill",
                                color: .orange
                            )
                        }
                        
                        // Chart
                        if !recentHistory.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Usage Trend")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Chart(recentHistory, id: \.timestamp) { entry in
                                    LineMark(
                                        x: .value("Time", entry.timestamp),
                                        y: .value("Usage %", entry.percentage)
                                    )
                                    .foregroundStyle(.blue)
                                    .interpolationMethod(.catmullRom)
                                    
                                    AreaMark(
                                        x: .value("Time", entry.timestamp),
                                        y: .value("Usage %", entry.percentage)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue.opacity(0.3), .clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .interpolationMethod(.catmullRom)
                                }
                                .chartYScale(domain: 0...100)
                                .chartXAxis {
                                    AxisMarks(values: .automatic) { value in
                                        AxisGridLine()
                                        AxisValueLabel(format: .dateTime.day().month())
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks { value in
                                        AxisGridLine()
                                        AxisValueLabel {
                                            if let intValue = value.as(Int.self) {
                                                Text("\(intValue)%")
                                            }
                                        }
                                    }
                                }
                                .frame(height: 200)
                                .padding(.vertical, 8)
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Export Button
                        VStack(spacing: 8) {
                            Button {
                                exportData()
                            } label: {
                                Label("Export to CSV", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.borderedProminent)
                            
                            if let url = exportedFileURL {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Exported to Downloads")
                                        .font(.caption)
                                    Button("Show") {
                                        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                                    }
                                    .buttonStyle(.link)
                                    .font(.caption)
                                }
                            }
                        }
                        
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.xyaxis.line")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("No Statistics Available")
                                .font(.headline)
                            Text("Usage data will appear here as you use the app")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
                }
                .padding()
            }
        }
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        statistics = UsageHistoryManager.shared.getStatistics()
        recentHistory = UsageHistoryManager.shared.getEntriesForLastDays(selectedDays)
    }
    
    private func exportData() {
        if let url = UsageHistoryManager.shared.saveCSVToFile() {
            exportedFileURL = url
            showingExportSuccess = true
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    StatisticsView()
        .frame(width: 400, height: 500)
}
