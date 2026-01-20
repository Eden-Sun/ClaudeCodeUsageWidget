import SwiftUI

struct UsageView: View {
    @StateObject private var monitor = UsageMonitor()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Claude Code Usage")
                    .font(.headline)
                Spacer()
            }
            .padding()
            
            Divider()
            
            usageView
        }
        .frame(width: AppConfig.popoverWidth, height: AppConfig.popoverHeight)
        .onAppear {
            monitor.startMonitoring()
        }
    }
    
    var usageView: some View {
        ScrollView {
            VStack(spacing: 20) {
                if monitor.isLoading {
                    ProgressView()
                        .padding()
                } else if let usage = monitor.currentUsage {
                    // Usage Circle
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: AppConfig.progressLineWidth)
                            .frame(width: AppConfig.progressCircleSize, height: AppConfig.progressCircleSize)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(usage.usagePercentage / 100))
                            .stroke(
                                colorForUsage(usage.usagePercentage),
                                style: StrokeStyle(lineWidth: AppConfig.progressLineWidth, lineCap: .round)
                            )
                            .frame(width: AppConfig.progressCircleSize, height: AppConfig.progressCircleSize)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut, value: usage.usagePercentage)
                        
                        VStack {
                            Text("\(Int(usage.usagePercentage))%")
                                .font(.system(size: 36, weight: .bold))
                            Text("used")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    
                    // Usage Details
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(
                            icon: "checkmark.circle.fill",
                            label: "Used",
                            value: "\(usage.used)",
                            color: .blue
                        )
                        
                        DetailRow(
                            icon: "arrow.right.circle.fill",
                            label: "Remaining",
                            value: "\(usage.remainingRequests)",
                            color: .green
                        )
                        
                        DetailRow(
                            icon: "chart.bar.fill",
                            label: "Total Limit",
                            value: "\(usage.limit)",
                            color: .purple
                        )
                        
                        if let resetDate = usage.resetDate {
                            DetailRow(
                                icon: "clock.fill",
                                label: "Resets",
                                value: formatResetDate(resetDate),
                                color: .orange
                            )
                        }
                    }
                    .padding()
                    
                } else if let error = monitor.error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text("Error Loading Usage")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry") {
                            monitor.fetchUsage()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)
                        Text("No Usage Data")
                            .font(.headline)
                        Text("Click refresh to load usage")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                Spacer()
                
                // Refresh Button
                Button(action: { monitor.fetchUsage() }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                }
                .buttonStyle(.bordered)
                .padding(.bottom)
            }
            .padding()
        }
    }
    
    func colorForUsage(_ percentage: Double) -> Color {
        switch percentage {
        case AppConfig.UsageThresholds.green:
            return .green
        case AppConfig.UsageThresholds.yellow:
            return .yellow
        case AppConfig.UsageThresholds.orange:
            return .orange
        case AppConfig.UsageThresholds.red:
            return .red
        default:
            return .purple
        }
    }
    
    func formatResetDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    UsageView()
}
