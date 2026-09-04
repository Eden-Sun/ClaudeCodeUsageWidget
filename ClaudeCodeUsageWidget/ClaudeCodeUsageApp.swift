import SwiftUI

@main
struct ClaudeCodeUsageWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(usageMonitor: appDelegate.usageMonitor)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    /// Not @Published: SwiftUI would only observe the reference being replaced,
    /// never the monitor's own @Published mutations. Views observe it directly.
    let usageMonitor = UsageMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        startMonitoring()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.title = "● --"
            button.action = #selector(statusBarClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        setupPopover()
    }

    func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: PopoverContentView.width(for: 1),
                                      height: PopoverContentView.height)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: PopoverContentView(usageMonitor: usageMonitor, appDelegate: self)
        )
    }

    @objc func statusBarClicked(_ sender: AnyObject?) {
        guard let button = statusItem?.button, let popover = popover else { return }

        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showContextMenu()
        } else {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
                // Opening the popover is an explicit "show me now" — don't make
                // the user stare at numbers up to 5 minutes old.
                usageMonitor.refreshIfStale()
            }
        }
    }

    func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r"))

        // Switching which profile drives the menu bar is a one-click job when
        // there is more than one to switch between.
        if usageMonitor.accounts.count > 1 {
            menu.addItem(NSMenuItem.separator())
            let header = NSMenuItem(title: "Menu bar shows", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)

            for account in usageMonitor.accounts {
                let item = NSMenuItem(title: "  \(account.account.label)",
                                      action: #selector(selectPrimary(_:)),
                                      keyEquivalent: "")
                item.target = self
                item.representedObject = account.account.service
                // Checked against the *resolved* primary, not the persisted
                // string: after the stored profile is logged out the menu bar
                // falls back to the first account, and comparing the raw string
                // would tick nothing at all.
                item.state = account.id == usageMonitor.primary?.id ? .on : .off
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc func selectPrimary(_ sender: NSMenuItem) {
        guard let service = sender.representedObject as? String else { return }
        usageMonitor.primaryService = service
    }

    @objc func refresh() {
        usageMonitor.fetchUsage()
    }

    @objc func showSettings() {
        popover?.performClose(nil)

        // Try multiple selectors for compatibility
        if !NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

    func startMonitoring() {
        usageMonitor.onUsageUpdate = { [weak self] in
            self?.updateMenuBar()
        }
        usageMonitor.startMonitoring()
    }

    /// One line per profile when there is more than one, at a smaller size so
    /// two stacked lines are still narrower than the single large line was —
    /// which matters on notched Macs, where an over-wide item pushes the whole
    /// menu bar row behind the notch.
    func updateMenuBar() {
        let accounts = usageMonitor.accounts

        // The SwiftUI frame widens with the column count; NSPopover has to be
        // told separately or the extra columns are clipped. It runs before the
        // empty-list bail-out because the shrink matters too: after the last
        // profile is logged out the popover otherwise keeps its multi-column
        // width around a one-column view, leaving a blank strip.
        popover?.contentSize = NSSize(width: PopoverContentView.width(for: accounts.count),
                                      height: PopoverContentView.height)

        guard let button = statusItem?.button else { return }

        guard !accounts.isEmpty else {
            // Explicit attributes rather than a bare string: a previous
            // multi-profile render left a 10.5pt font and a clamped line box
            // behind, and NSButton keeps those until something replaces them.
            button.attributedTitle = NSAttributedString(string: "● --", attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor
            ])
            button.toolTip = usageMonitor.error ?? UsageError.noAccounts.errorDescription
            return
        }

        // NSButton collapses to one line unless told otherwise.
        (button.cell as? NSButtonCell)?.usesSingleLineMode = false
        button.lineBreakMode = .byClipping

        let multiline = accounts.count > 1
        let ordered = usageMonitor.orderedForDisplay

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byClipping
        if multiline {
            // Two lines have to fit the ~24pt menu bar. Left to its natural
            // leading the block overflows and gets anchored to the top, which
            // reads as "sitting too high" — so clamp the line box and nudge the
            // baseline down to centre it.
            paragraph.maximumLineHeight = 10.5
            paragraph.minimumLineHeight = 10.5
        }

        let size: CGFloat = multiline ? 10.5 : NSFont.systemFontSize
        let baseline: CGFloat = multiline ? -2.5 : 0
        let title = NSMutableAttributedString()

        for (index, account) in ordered.enumerated() {
            if index > 0 { title.append(NSAttributedString(string: "\n")) }

            // A hollow dot marks a reading that could not be refreshed. It costs
            // no width — which a badge or an extra glyph would, and this row has
            // to stay clear of the notch — and pairs with the dimmed numbers.
            let dot = NSAttributedString(string: account.isStale ? "○ " : "● ", attributes: [
                .font: NSFont.systemFont(ofSize: size),
                .foregroundColor: dotColor(for: account),
                .paragraphStyle: paragraph,
                .baselineOffset: baseline
            ])
            title.append(dot)

            title.append(NSAttributedString(string: values(for: account), attributes: [
                // Monospaced digits keep the width stable as the numbers tick,
                // so the rest of the menu bar doesn't shuffle every refresh.
                .font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium),
                .foregroundColor: account.isStale ? NSColor.secondaryLabelColor : NSColor.labelColor,
                .paragraphStyle: paragraph,
                .baselineOffset: baseline
            ]))
        }

        button.attributedTitle = title
        button.toolTip = ordered.map(tooltip(for:)).joined(separator: "\n\n")
    }

    /// Neutral when there is no usable figure — a missing reading must not wear
    /// the same red as an exhausted quota.
    private func dotColor(for account: AccountUsage) -> NSColor {
        guard let remaining = account.snapshot?.headlineDisplayRemaining else {
            return .secondaryLabelColor
        }
        return NSColor(UsageStyle.color(remaining: remaining))
    }

    /// Remaining headroom: 5-hour, weekly, then Fable's weekly cap on Max.
    /// Always the same fields in the same order, so stacked rows line up.
    private func values(for account: AccountUsage) -> String {
        guard let usage = account.snapshot else { return UsageStyle.unknownValue }

        var values = [usage.headlineDisplayRemaining]
        if let weekly = usage.sevenDay {
            values.append(weekly.displayRemaining)
        }
        // Fable has its own weekly cap, but only Max plans get one worth
        // watching — don't spend menu bar width on it for Pro.
        if account.isMaxPlan == true, let fable = usage.fableLimit {
            values.append(fable.displayRemaining)
        }
        return values.map(UsageStyle.percentValue).joined(separator: " ")
    }

    private func tooltip(for account: AccountUsage) -> String {
        var lines: [String] = []
        if usageMonitor.accounts.count > 1 {
            lines.append(account.account.label + (account.planLabel.map { " · \($0)" } ?? ""))
        }
        if let email = account.email {
            lines.append(email)
        }
        // The menu bar's hollow dot says "stale"; the tooltip is where there is
        // room to say how stale, which is what decides whether to trust it.
        if account.isStale, let fetchedAt = account.snapshot?.fetchedAt {
            lines.append("Not refreshed — showing usage from "
                         + UsageStyle.relativeTime.localizedString(for: fetchedAt, relativeTo: Date()))
        }
        guard let usage = account.snapshot else { return lines.joined(separator: "\n") }

        lines.append("5-hour: " + UsageStyle.percentLeft(usage.headlineDisplayRemaining))
        if let weekly = usage.sevenDay {
            lines.append("Weekly: " + UsageStyle.percentLeft(weekly.displayRemaining))
        }
        for limit in usage.scopedLimits {
            lines.append("\(limit.displayName): " + UsageStyle.percentLeft(limit.displayRemaining))
        }
        return lines.joined(separator: "\n")
    }
}

extension UsageMonitor {
    /// Primary first — it is the one the eye should land on, and the menu bar
    /// rows and the popover's columns have to agree on which one that is or the
    /// first line describes a different profile than the first column.
    var orderedForDisplay: [AccountUsage] {
        guard let primary = primary else { return accounts }
        return [primary] + accounts.filter { $0.id != primary.id }
    }
}

/// Headroom as the UI is allowed to state it: nil once the window's reset time
/// has passed, because the figure then describes a window that has already
/// rolled over and the new one has not been read yet.
extension UsageWindow {
    var displayRemaining: Int? { hasReset ? nil : remainingPercent }
}

extension UsageLimit {
    var displayRemaining: Int? { hasReset ? nil : remainingPercent }
}

extension UsageSnapshot {
    var headlineDisplayRemaining: Int? { headline.flatMap { $0.displayRemaining } }
}

// MARK: - Shared styling

/// Everything here is keyed on *remaining* headroom, which is what the UI shows.
enum UsageStyle {
    /// Shown wherever a number is genuinely unknown. Not "0" — an unreadable
    /// profile and an exhausted one have to look different.
    static let unknownValue = "--"

    static func color(remaining: Int) -> Color {
        if remaining > 50 { return .green }
        if remaining > 20 { return .yellow }
        return .red
    }

    /// Neutral for nil, so "no data" never renders in the same red as "empty".
    static func color(remaining: Int?) -> Color {
        guard let remaining = remaining else { return .secondary }
        return color(remaining: remaining)
    }

    static func percentValue(_ remaining: Int?) -> String {
        remaining.map(String.init) ?? unknownValue
    }

    static func percentLeft(_ remaining: Int?) -> String {
        remaining.map { "\($0)% left" } ?? unknownValue
    }

    /// A window past its reset time: the old percentage is meaningless and the
    /// new one is not in hand yet, so say that rather than guess.
    static let resetLabel = "Window has reset"

    static let relativeTime: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
}

// MARK: - Popover Content

struct PopoverContentView: View {
    /// Observed directly — the monitor's @Published changes don't propagate
    /// through AppDelegate, so observing the delegate would leave this stale.
    @ObservedObject var usageMonitor: UsageMonitor
    let appDelegate: AppDelegate

    /// Each profile gets its own column; the popover widens to match.
    static let columnWidth: CGFloat = 240
    static let chrome: CGFloat = 32
    static let height: CGFloat = 420

    static func width(for accountCount: Int) -> CGFloat {
        let columns = CGFloat(max(1, min(accountCount, 3)))
        return columns * columnWidth + chrome
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Claude Usage")
                    .font(.headline)
                Spacer()
                Button(action: { usageMonitor.fetchUsage() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(usageMonitor.isLoading)
            }

            Divider()

            if usageMonitor.accounts.isEmpty {
                Spacer()
                if usageMonitor.isLoading {
                    ProgressView("Loading...")
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(usageMonitor.error ?? "No accounts found")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") { usageMonitor.fetchUsage() }
                            .buttonStyle(.bordered)
                    }
                }
                Spacer()
            } else {
                // Side-by-side columns, one per profile. Beyond three the row
                // scrolls rather than squeezing every column narrower.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 0) {
                        let ordered = usageMonitor.orderedForDisplay
                        ForEach(ordered) { account in
                            AccountColumnView(
                                account: account,
                                isPrimary: account.id == usageMonitor.primary?.id
                            )
                            .frame(width: Self.columnWidth)

                            if account.id != ordered.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }

            Divider()

            HStack {
                Button("Settings") { appDelegate.showSettings() }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(.plain)
            .font(.caption)
        }
        .padding()
        .frame(width: Self.width(for: usageMonitor.accounts.count), height: Self.height)
    }
}

/// One profile's column: header, 5-hour gauge, then its weekly bars.
struct AccountColumnView: View {
    let account: AccountUsage
    let isPrimary: Bool

    var body: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(account.account.label)
                        .font(.caption)
                        .fontWeight(.semibold)
                    if let plan = account.planLabel {
                        Text(plan)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if isPrimary {
                        Image(systemName: "menubar.arrow.up.rectangle")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .help("Shown in the menu bar")
                    }
                    Spacer()
                }

                if let email = account.email {
                    // Addresses routinely overflow a 240pt column; keep the
                    // domain visible since that is what distinguishes accounts.
                    Text(email)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .help(email)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let usage = account.snapshot {
                if account.isStale {
                    StaleNoticeView(account: account)
                }
                GaugeView(remaining: usage.headlineDisplayRemaining,
                          resetsAt: usage.headline?.resetsAt,
                          hasReset: usage.headline?.hasReset ?? false)

                VStack(spacing: 8) {
                    if let weekly = usage.sevenDay {
                        UsageBar(label: "Weekly",
                                 remaining: weekly.displayRemaining,
                                 resetsAt: weekly.resetsAt,
                                 hasReset: weekly.hasReset)
                    }
                    ForEach(usage.scopedLimits) { limit in
                        UsageBar(label: limit.displayName,
                                 remaining: limit.displayRemaining,
                                 resetsAt: limit.resetsAt,
                                 hasReset: limit.hasReset)
                    }
                }
            } else {
                Spacer(minLength: 12)
                SignedOutView(account: account)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
    }
}

/// Shown above numbers that could not be refreshed on this poll. The reading
/// is real but dated, so it is labelled rather than hidden — and the command
/// that puts the profile back in sync is right there.
struct StaleNoticeView: View {
    let account: AccountUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                Text(account.error?.errorDescription ?? "Not refreshed")
                    .font(.system(size: 10))
                    .lineLimit(2)
            }
            if let fetchedAt = account.snapshot?.fetchedAt {
                Text("Showing usage from \(UsageStyle.relativeTime.localizedString(for: fetchedAt, relativeTo: Date())).")
                    .font(.system(size: 9))
            }
            Text(account.account.loginHint)
                .font(.system(size: 9, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(.orange)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(5)
    }
}

/// A profile whose token has lapsed isn't an error worth shouting about — it
/// just needs that profile to be used once. Show the exact command.
struct SignedOutView: View {
    let account: AccountUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: "moon.zzz")
                .font(.title2)
                .foregroundColor(.secondary)
            Text(account.error?.errorDescription ?? "Unavailable")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(account.account.loginHint)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 3)
                .padding(.horizontal, 5)
                .background(Color.gray.opacity(0.12))
                .cornerRadius(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GaugeView: View {
    /// nil when there is nothing trustworthy to show — no window in the
    /// response, or one that has already rolled over.
    let remaining: Int?
    let resetsAt: Date?
    let hasReset: Bool

    private var fraction: CGFloat {
        guard let remaining = remaining else { return 0 }
        return CGFloat(min(Double(remaining), 100) / 100)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(UsageStyle.color(remaining: remaining),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: remaining)

                VStack(spacing: 2) {
                    Text(remaining.map { "\($0)%" } ?? UsageStyle.unknownValue)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("5-hour left")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 100, height: 100)

            // `style: .relative` renders a past date without direction, so a
            // window that reset three hours ago would read "Resets 3 hr".
            if hasReset {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text(UsageStyle.resetLabel)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            } else if let resetsAt = resetsAt {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text("Resets \(resetsAt, style: .relative)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }
}

struct UsageBar: View {
    let label: String
    let remaining: Int?
    let resetsAt: Date?
    let hasReset: Bool

    private var fraction: CGFloat {
        guard let remaining = remaining else { return 0 }
        return CGFloat(min(Double(remaining), 100) / 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.caption)
                Spacer()
                Text(UsageStyle.percentLeft(remaining))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(UsageStyle.color(remaining: remaining))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                    Capsule()
                        .fill(UsageStyle.color(remaining: remaining))
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 6)

            if hasReset {
                Text(UsageStyle.resetLabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else if let resetsAt = resetsAt {
                Text("Resets \(resetsAt, style: .relative)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var usageMonitor: UsageMonitor

    /// Reads the *resolved* primary rather than the persisted string: once the
    /// stored profile is logged out the menu bar tracks the fallback, and a
    /// picker bound to the raw string would select nothing and have SwiftUI
    /// complain about an invalid selection.
    private var primarySelection: Binding<String> {
        Binding(get: { usageMonitor.primary?.account.service ?? usageMonitor.primaryService },
                set: { usageMonitor.primaryService = $0 })
    }

    /// From the bundle, not a literal — a hardcoded string drifts from
    /// Info.plist the first release nobody remembers to bump it.
    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (short, build) {
        case let (short?, build?) where short != build: return "\(short) (\(build))"
        case let (short?, _): return short
        default: return "unknown"
        }
    }

    var body: some View {
        Form {
            Section("Menu Bar") {
                if usageMonitor.accounts.isEmpty {
                    Text("No Claude Code profiles found.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                } else {
                    Picker("Show account", selection: primarySelection) {
                        ForEach(usageMonitor.accounts) { account in
                            Text(account.account.label + (account.planLabel.map { " — \($0)" } ?? ""))
                                .tag(account.account.service)
                        }
                    }
                    Text("The popover always lists every profile; this picks which one the menu bar tracks.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Profiles") {
                ForEach(usageMonitor.accounts) { account in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(account.account.label)
                                .fontWeight(.semibold)
                            if let plan = account.planLabel {
                                Text(plan).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(account.error == nil ? "active" : (account.isStale ? "stale" : "signed out"))
                                .font(.caption)
                                .foregroundColor(account.error == nil ? .green : (account.isStale ? .orange : .secondary))
                        }
                        if let email = account.email {
                            Text(email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                        if let dir = account.account.configDir {
                            Text(dir.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.vertical, 1)
                }

                Text("Profiles come from Claude Code itself — each CLAUDE_CONFIG_DIR gets its own Keychain slot. Log one in and it appears here; there is nothing to configure in this app.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("About") {
                LabeledContent("Version", value: version)
                Text("Menu bar monitor for Claude Code's 5-hour and weekly usage limits.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 460)
        .onAppear { usageMonitor.refreshIfStale() }
    }
}
