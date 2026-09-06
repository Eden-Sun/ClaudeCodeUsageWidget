import SwiftUI
import os.log

@main
struct ClaudeCodeUsageWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// Deliberately empty.
    ///
    /// The settings window used to live here as a `Settings` scene, opened with
    /// the `showSettingsWindow:` selector. In this app that silently did
    /// nothing: the scene is not reliably instantiated in an accessory
    /// (`LSUIElement`) app that never opens a window of its own, and the
    /// selector is private, so a miss reports success and leaves no trace. The
    /// window is built by the delegate instead, where it can be held onto and
    /// checked.
    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    /// Held so the window is reused rather than rebuilt, and so it survives
    /// being closed — a window released on close would take the hosting
    /// controller, and the settings state, with it.
    private var settingsWindow: NSWindow?
    private let logger = Logger(subsystem: "com.claudecode.usagewidget", category: "AppDelegate")
    /// Not @Published: SwiftUI would only observe the reference being replaced,
    /// never the monitor's own @Published mutations. Views observe it directly.
    let usageMonitor = UsageMonitor()
    let grokMonitor = GrokMonitor()

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
            rootView: PopoverContentView(usageMonitor: usageMonitor,
                                         grokMonitor: grokMonitor,
                                         appDelegate: self)
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
                grokMonitor.refreshIfStale()
            }
        }
    }

    func showContextMenu() {
        let menu = NSMenu()
        // Every item targets self explicitly. A nil target sends the action up
        // the responder chain, which happens to reach the app delegate — but
        // only by way of NSApp, and only while nothing else has claimed first
        // responder. Naming the target removes the coincidence.
        menu.addItem(item(title: "Refresh", action: #selector(refresh), key: "r"))

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
        menu.addItem(item(title: "Settings...", action: #selector(showSettings), key: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(item(title: "Quit", action: #selector(quit), key: "q"))

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    private func item(title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc func selectPrimary(_ sender: NSMenuItem) {
        guard let service = sender.representedObject as? String else { return }
        usageMonitor.primaryService = service
    }

    @objc func refresh() {
        usageMonitor.fetchUsage()
        grokMonitor.fetch()
    }

    @objc func showSettings() {
        popover?.performClose(nil)

        // Deferred because this runs *during* the status menu's tracking
        // session, and a window ordered front in that state is dropped — the
        // menu closes and nothing appears. The next runloop pass is after
        // tracking has ended.
        DispatchQueue.main.async { self.presentSettings() }
    }

    private func presentSettings() {
        let window = settingsWindow ?? makeSettingsWindow()
        settingsWindow = window

        // Before ordering front, not after: an accessory app that isn't active
        // can order a window front and still have it appear behind whatever the
        // user was looking at.
        NSApp.activate(ignoringOtherApps: true)
        if !window.isVisible { window.center() }
        window.makeKeyAndOrderFront(nil)

        logger.info("settings window visible=\(window.isVisible, privacy: .public) key=\(window.isKeyWindow, privacy: .public)")
    }

    private func makeSettingsWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentViewController = NSHostingController(
            rootView: SettingsView(usageMonitor: usageMonitor, grokMonitor: grokMonitor)
        )
        // Closing must not destroy it: the delegate keeps the only reference,
        // and a released window would leave that reference dangling.
        window.isReleasedWhenClosed = false
        return window
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

    func startMonitoring() {
        usageMonitor.onUsageUpdate = { [weak self] in
            self?.updateMenuBar()
        }
        grokMonitor.onUpdate = { [weak self] in
            self?.updateMenuBar()
        }
        usageMonitor.startMonitoring()
        grokMonitor.startMonitoring()
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

        // Built at the fullest detail that fits, dropping the least urgent
        // figures rather than letting the item run under the notch. macOS does
        // not truncate a status item that no longer fits — it hides it — so an
        // item that overruns disappears entirely, which is the worst outcome of
        // the three.
        let title: NSAttributedString
        if let forced = Detail(rawValue: usageMonitor.menuBarDetail) {
            title = menuBarTitle(detail: forced)
        } else {
            // Automatic: the fullest detail that fits the budget. macOS does not
            // truncate a status item that no longer fits — it hides it — so an
            // item that overruns disappears entirely, which is the worst of the
            // three outcomes.
            var candidate = menuBarTitle(detail: .full)
            let budget = menuBarWidthBudget()
            for detail in Detail.allCases.dropFirst() where candidate.size().width > budget {
                candidate = menuBarTitle(detail: detail)
            }
            title = candidate
        }

        button.attributedTitle = title
        // The tooltip always carries everything, whatever the title had room
        // for — that is where a dropped figure goes, not away.
        var tooltips = usageMonitor.orderedForDisplay.map(tooltip(for:))
        if let grokTooltip = grokTooltip() { tooltips.append(grokTooltip) }
        button.toolTip = tooltips.joined(separator: "\n\n")
    }

    /// The widest the status item may be.
    ///
    /// `auxiliaryTopRightArea` is the strip of menu bar to the right of the
    /// notch — the region status items actually live in — and is nil on a
    /// display without one, where the whole width is available. Half of it is
    /// the budget: the other half has to hold everyone else's items, and this
    /// app is not entitled to more than its share. The 420pt floor keeps a
    /// narrow external display from squeezing the item to nothing.
    private func menuBarWidthBudget() -> CGFloat {
        guard let screen = NSScreen.main else { return 420 }
        let available = screen.auxiliaryTopRightArea?.width ?? screen.frame.width
        return max(220, min(available * 0.5, 420))
    }

    /// Lays the entries out as a grid at one detail level.
    private func menuBarTitle(detail: Detail) -> NSAttributedString {
        // One entry per thing worth reporting: each Claude profile, then Grok.
        // Built as a flat list first because how many *rows* they get is a
        // separate decision from how many entries there are.
        let ordered = usageMonitor.orderedForDisplay
        var entries: [(text: String, color: NSColor, stale: Bool)] = ordered.map {
            (values(for: $0, detail: detail), dotColor(for: $0), $0.isStale)
        }
        if let grokLine = grokMenuBarLine(detail: detail) {
            entries.append((grokLine, grokDotColor(),
                            grokMonitor.usage != nil && grokMonitor.error != nil))
        }
        guard !entries.isEmpty else { return NSAttributedString() }

        // Two rows, filled top-to-bottom then left-to-right, so four entries
        // read as a grid:
        //
        //     cc0   cc2
        //     cc1   grok
        //
        // Two is the ceiling and the menu bar sets it, not taste: the row is
        // ~22pt and two 10.5pt lines already fill it, so a third would need
        // about 7pt — past legible. Growing sideways instead keeps every entry
        // full size. Column-major because a new profile should push the layout
        // wider rather than reshuffling which row the existing ones sit on.
        let rowCount = entries.count > 1 ? 2 : 1
        let columnCount = (entries.count + rowCount - 1) / rowCount
        var grid: [[(text: String, color: NSColor, stale: Bool)?]] =
            Array(repeating: Array(repeating: nil, count: columnCount), count: rowCount)
        for (index, entry) in entries.enumerated() {
            grid[index % rowCount][index / rowCount] = entry
        }

        let multiline = rowCount > 1
        let size: CGFloat = multiline ? 10.5 : NSFont.systemFontSize
        let baseline: CGFloat = multiline ? -2.5 : 0
        let dotFont = NSFont.systemFont(ofSize: size)
        let textFont = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium)

        /// One cell, without the paragraph style — that is applied to the whole
        /// string at the end, once the tab stops are known.
        func cell(_ entry: (text: String, color: NSColor, stale: Bool)) -> NSAttributedString {
            let result = NSMutableAttributedString()
            // A hollow dot marks a reading that could not be refreshed. It costs
            // no width — which a badge or an extra glyph would, and this row has
            // to stay clear of the notch — and pairs with the dimmed numbers.
            result.append(NSAttributedString(string: entry.stale ? "\u{25CB} " : "\u{25CF} ",
                                             attributes: [.font: dotFont, .foregroundColor: entry.color]))
            // Monospaced digits keep the width stable as the numbers tick, so
            // the rest of the menu bar doesn't shuffle every refresh.
            result.append(NSAttributedString(string: entry.text, attributes: [
                .font: textFont,
                .foregroundColor: entry.stale ? NSColor.secondaryLabelColor : NSColor.labelColor
            ]))
            return result
        }

        let cells = grid.map { row in row.map { $0.map(cell) } }

        // Tab stops rather than padding spaces: the columns hold different
        // labels ("84 59" against "Grok 86"), so spaces would leave the second
        // column ragged between rows.
        let gutter: CGFloat = 10
        var tabStops: [NSTextTab] = []
        var offset: CGFloat = 0
        for column in 0..<columnCount {
            let widest = cells.compactMap { $0[column]?.size().width }.max() ?? 0
            offset += widest + gutter
            if column + 1 < columnCount {
                tabStops.append(NSTextTab(textAlignment: .left, location: offset))
            }
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byClipping
        paragraph.tabStops = tabStops
        if multiline {
            // Left to its natural leading the block overflows and gets anchored
            // to the top, which reads as "sitting too high" — so clamp the line
            // box and nudge the baseline down to centre it.
            paragraph.maximumLineHeight = 10.5
            paragraph.minimumLineHeight = 10.5
        }

        let title = NSMutableAttributedString()
        for (rowIndex, row) in cells.enumerated() {
            if rowIndex > 0 { title.append(NSAttributedString(string: "\n")) }
            for (columnIndex, cell) in row.enumerated() {
                if columnIndex > 0 { title.append(NSAttributedString(string: "\t")) }
                // A short column can run out of entries before the row does;
                // the tab still has to be written so the next column lines up.
                if let cell = cell { title.append(cell) }
            }
        }
        title.addAttributes([.paragraphStyle: paragraph, .baselineOffset: baseline],
                            range: NSRange(location: 0, length: title.length))
        return title
    }

    /// The Grok row's text, or nil when there is no cookie on file — an
    /// unconfigured Grok must not cost a menu bar line, least of all on a
    /// notched Mac.
    private func grokMenuBarLine(detail: Detail = .full) -> String? {
        // A Grok row is earned by having something to say. With no CLI on the
        // machine there is nothing to report, and a menu bar line costs width
        // that matters on a notched Mac.
        guard grokMonitor.isAvailable else { return nil }
        // "G" once space is tight: the dot's colour and the popover carry the
        // rest, and a truncated item is worse than a terse one.
        let label = detail == .headline ? "G" : "Grok"
        guard let remaining = grokMonitor.usage?.displayRemaining else {
            return label + " " + UsageStyle.unknownValue
        }
        return label + " " + UsageStyle.percentValue(remaining)
    }

    private func grokDotColor() -> NSColor {
        guard let remaining = grokMonitor.usage?.displayRemaining else {
            return .secondaryLabelColor
        }
        return NSColor(UsageStyle.color(remaining: remaining))
    }

    private func grokTooltip() -> String? {
        guard grokMonitor.isAvailable else { return nil }
        var lines = ["Grok" + (grokMonitor.usage?.tier.map { " · \($0)" } ?? "")]
        if let usage = grokMonitor.usage {
            lines.append(usage.periodLabel + ": " + UsageStyle.percentLeft(usage.displayRemaining))
            if let end = usage.periodEnd {
                lines.append("Resets " + UsageStyle.relativeTime.localizedString(for: end, relativeTo: Date()))
            }
            if grokMonitor.error != nil {
                lines.append("Not refreshed — showing usage from "
                             + UsageStyle.relativeTime.localizedString(for: usage.fetchedAt, relativeTo: Date()))
            }
        }
        if let error = grokMonitor.error {
            lines.append(error.localizedDescription)
        }
        return lines.joined(separator: "\n")
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
    /// How much of each reading the menu bar has room for.
    ///
    /// Ordered by what gets dropped first. The 5-hour figure is the one that
    /// bites soonest and is never dropped; the scoped cap is the most
    /// specialised and goes first.
    enum Detail: Int, CaseIterable, Comparable {
        case full = 0       // 5-hour, weekly, scoped
        case noScoped = 1   // 5-hour, weekly
        case headline = 2   // 5-hour only

        static func < (a: Detail, b: Detail) -> Bool { a.rawValue < b.rawValue }
    }

    private func values(for account: AccountUsage, detail: Detail) -> String {
        guard let usage = account.snapshot else { return UsageStyle.unknownValue }

        var values = [usage.headlineDisplayRemaining]
        if detail <= .noScoped, let weekly = usage.sevenDay {
            values.append(weekly.displayRemaining)
        }
        // Fable has its own weekly cap, but only Max plans get one worth
        // watching — don't spend menu bar width on it for Pro.
        if detail == .full, account.isMaxPlan == true, let fable = usage.fableLimit {
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
    @ObservedObject var grokMonitor: GrokMonitor
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

            if grokMonitor.isAvailable {
                Divider()
                GrokRowView(monitor: grokMonitor)
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

/// The Grok line in the popover: label, remaining headroom, and a bar.
///
/// A row rather than a column. Grok contributes one figure, not the stack of
/// session/weekly/per-model caps a Claude profile does, and giving it a column
/// of its own would leave most of that column empty.
struct GrokRowView: View {
    @ObservedObject var monitor: GrokMonitor

    private var isStale: Bool { monitor.usage != nil && monitor.error != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Grok")
                    .font(.caption)
                    .fontWeight(.semibold)
                if let usage = monitor.usage {
                    Text(usage.periodLabel)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(UsageStyle.percentLeft(monitor.usage?.displayRemaining))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(isStale ? .secondary : .primary)
            }

            if let remaining = monitor.usage?.displayRemaining {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.2))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(UsageStyle.color(remaining: remaining).opacity(isStale ? 0.4 : 1))
                            .frame(width: geometry.size.width * CGFloat(remaining) / 100)
                    }
                }
                .frame(height: 6)
            }

            if let end = monitor.usage?.periodEnd, monitor.error == nil {
                Text("Resets " + UsageStyle.relativeTime.localizedString(for: end, relativeTo: Date()))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let error = monitor.error {
                Text(error.localizedDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var usageMonitor: UsageMonitor
    @ObservedObject var grokMonitor: GrokMonitor

    @State private var showsGrokPathEntry = false
    @State private var grokPathDraft = ""

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

    /// What the Grok section reports: the live figure when the CLI answers, the
    /// failure when it doesn't. A bare "configured" would be useless — a CLI
    /// that is installed but signed out looks identical.
    private var grokStatusText: String {
        if let error = grokMonitor.error {
            return error.localizedDescription.replacingOccurrences(of: "\n", with: " ")
        }
        guard let usage = grokMonitor.usage else { return "Checking…" }
        guard let remaining = usage.displayRemaining else { return "Period rolled over — refreshing" }
        return "\(usage.periodLabel): \(remaining)% left"
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

                Picker("Detail", selection: $usageMonitor.menuBarDetail) {
                    Text("Automatic").tag(-1)
                    Text("5-hour, weekly, per-model").tag(0)
                    Text("5-hour, weekly").tag(1)
                    Text("5-hour only").tag(2)
                }
                Text("""
                    Automatic shows as much as fits. Narrow it by hand if the menu bar is \
                    crowded — on a Mac with a notch, macOS hides items it cannot fit rather \
                    than shrinking them, and this app cannot see how much room other apps' \
                    items take. Whatever is dropped stays in the tooltip and the popover.
                    """)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Grok") {
                HStack {
                    Text(grokStatusText)
                        .font(.callout)
                        .foregroundColor(grokMonitor.error == nil ? .primary : .orange)
                    Spacer()
                    if let tier = grokMonitor.usage?.tier {
                        Text(tier).font(.caption).foregroundColor(.secondary)
                    }
                }

                if let path = grokMonitor.cliPath {
                    Text(path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }

                DisclosureGroup("Grok CLI is somewhere else", isExpanded: $showsGrokPathEntry) {
                    TextField("/path/to/grok", text: $grokPathDraft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { grokMonitor.cliPathOverride = grokPathDraft }
                    HStack {
                        Button("Use this path") { grokMonitor.cliPathOverride = grokPathDraft }
                            .disabled(grokPathDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Reset") {
                            grokPathDraft = ""
                            grokMonitor.cliPathOverride = nil
                        }
                        Spacer()
                    }
                }
                .font(.caption)

                Text("""
                    Read from the Grok CLI, which is already signed in — nothing to \
                    configure and no cookie to paste. The app asks it for the billing \
                    period over its own protocol; no model is called and no quota is \
                    spent. If the row is empty, run `grok login` in a terminal.
                    """)
                    .font(.caption)
                    .foregroundColor(.secondary)
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
        .frame(minWidth: 520, minHeight: 560)
        .onAppear {
            usageMonitor.refreshIfStale()
            grokMonitor.refreshIfStale()
        }
    }
}
