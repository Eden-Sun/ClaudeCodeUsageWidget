import Foundation
import os.log

// MARK: - Model

/// The Grok subscription's current billing period, as the Grok CLI reports it.
///
/// `creditUsagePercent` is consumption, like everything Anthropic returns, and
/// like those it is turned into headroom at the edge where it is displayed.
struct GrokUsage {
    let usedPercent: Double
    let periodStart: Date?
    let periodEnd: Date?
    /// "WEEKLY" and friends, straight from `currentPeriod.type` with the
    /// `USAGE_PERIOD_TYPE_` prefix removed.
    let periodKind: String?
    /// "SuperGrok", "SuperGrok Heavy", …
    let tier: String?
    let fetchedAt: Date

    var percent: Int { Int(usedPercent.rounded()) }
    var remainingPercent: Int { max(0, 100 - percent) }

    /// True once the period's end has passed — the figure then describes a week
    /// that has already rolled over, and the new one hasn't been read yet.
    var hasReset: Bool {
        guard let periodEnd = periodEnd else { return false }
        return periodEnd <= Date()
    }

    /// Headroom as the UI is allowed to state it.
    var displayRemaining: Int? { hasReset ? nil : remainingPercent }

    var periodLabel: String {
        guard let kind = periodKind else { return "Usage" }
        return kind.capitalized   // "WEEKLY" -> "Weekly"
    }
}

enum GrokError: LocalizedError, Equatable {
    case cliNotFound
    case notSignedIn
    case timedOut
    case protocolFailure(String)

    var errorDescription: String? {
        switch self {
        case .cliNotFound:
            return "Grok CLI not found.\nInstall it, or set its path in Settings → Grok."
        case .notSignedIn:
            return "Grok CLI is not signed in.\nRun `grok login` in a terminal."
        case .timedOut:
            return "Grok CLI did not answer in time."
        case .protocolFailure(let message):
            return "Grok CLI: \(message)"
        }
    }
}

// MARK: - Monitor

/// Reads the Grok subscription's weekly usage by asking the Grok CLI.
///
/// Not by calling grok.com. That was tried and cannot work: the site is behind
/// Cloudflare, whose clearance cookie is bound to the IP, the User-Agent *and*
/// the TLS/JA3 fingerprint of the client that solved the challenge. A native
/// URLSession has its own fingerprint, so a cookie copied out of a browser is
/// dead on first use — and a request whose TLS says "URLSession" while its
/// User-Agent claims to be Chrome looks more like a bot than one that never
/// lied. No amount of header juggling gets past that.
///
/// The CLI already holds a working OAuth session (`~/.grok/auth.json`), and it
/// speaks ACP over stdio. `_x.ai/billing` answers with the billing period and
/// the percentage consumed, which is exactly the figure wanted here. It needs
/// only the `initialize` handshake — no session, so nothing is written to disk
/// and no model call is made. The whole exchange takes about a second.
class GrokMonitor: ObservableObject {
    @Published var usage: GrokUsage?
    @Published var error: GrokError?
    @Published var isLoading = false

    /// Whether the CLI could be located at all. Drives the Settings UI.
    @Published var isAvailable = false

    var onUpdate: (() -> Void)?

    /// Kept across a failed poll so a CLI that is briefly unreachable doesn't
    /// blank a reading that is still broadly true — a weekly figure ages well.
    private var lastGood: GrokUsage?

    private let logger = Logger(subsystem: "com.claudecode.usagewidget", category: "GrokMonitor")
    private var isFetching = false
    private var timer: Timer?
    /// Matches the Claude poll interval. A weekly figure moves slowly, and each
    /// poll spawns a process, so there is nothing to gain from asking often.
    private let updateInterval: TimeInterval = 300
    /// Generous: the CLI answers in about a second, but a cold start after an
    /// update has to fetch and verify its own binaries first.
    private let callTimeout: TimeInterval = 30

    /// Where to look for the CLI. `~/.local/bin` is where its installer puts
    /// it; the rest cover Homebrew on both architectures. `PATH` is not
    /// consulted — an app launched from Finder inherits the launchd
    /// environment, not a shell's, so `PATH` here is a short system default
    /// that would never contain any of these.
    private static let searchPaths = [
        "~/.local/bin/grok",
        "/opt/homebrew/bin/grok",
        "/usr/local/bin/grok",
        "~/.grok/bin/grok"
    ]

    /// An explicit path set in Settings, for an install somewhere else.
    private static let overrideKey = "grok_cli_path"
    var cliPathOverride: String? {
        get { UserDefaults.standard.string(forKey: Self.overrideKey) }
        set {
            let cleaned = newValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set((cleaned?.isEmpty ?? true) ? nil : cleaned, forKey: Self.overrideKey)
            fetch()
        }
    }

    /// The CLI's location, or nil if it isn't installed anywhere known.
    var cliPath: String? {
        if let override = cliPathOverride, FileManager.default.isExecutableFile(atPath: override) {
            return override
        }
        return Self.searchPaths
            .map { NSString(string: $0).expandingTildeInPath }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    // MARK: - Lifecycle

    func startMonitoring() {
        fetch()
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.fetch()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func refreshIfStale(maxAge: TimeInterval = 30) {
        guard error == nil, let fetchedAt = usage?.fetchedAt,
              Date().timeIntervalSince(fetchedAt) <= maxAge else {
            fetch()
            return
        }
    }

    // MARK: - Poll

    func fetch() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.fetch() }
            return
        }
        guard !isFetching else { return }

        guard let cliPath = cliPath else {
            isAvailable = false
            usage = nil
            lastGood = nil
            error = .cliNotFound
            onUpdate?()
            return
        }
        isAvailable = true
        isFetching = true
        isLoading = true

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let result = Self.readBilling(cliPath: cliPath, timeout: self.callTimeout)
            DispatchQueue.main.async {
                self.isFetching = false
                self.isLoading = false
                switch result {
                case .success(let usage):
                    self.lastGood = usage
                    self.usage = usage
                    self.error = nil
                    self.logger.info("grok \(usage.periodLabel, privacy: .public): \(usage.remainingPercent, privacy: .public)% left")
                case .failure(let error):
                    self.usage = self.lastGood
                    self.error = error
                }
                self.onUpdate?()
            }
        }
    }

    // MARK: - ACP

    /// Runs one `initialize` + `_x.ai/billing` exchange against `grok agent stdio`.
    ///
    /// Synchronous and short-lived on purpose: the process exists only for the
    /// two requests and is killed on the way out, so there is no long-running
    /// child to supervise, and a hung CLI costs one timeout rather than a
    /// permanently wedged monitor.
    private static func readBilling(cliPath: String, timeout: TimeInterval) -> Result<GrokUsage, GrokError> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliPath)
        process.arguments = ["agent", "stdio"]
        // The CLI reads per-directory configuration on startup, so it is given
        // the home directory rather than whatever the app was launched from.
        process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())

        let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            return .failure(.protocolFailure(error.localizedDescription))
        }

        defer {
            if process.isRunning { process.terminate() }
            try? stdin.fileHandleForWriting.close()
            try? stdout.fileHandleForReading.close()
            try? stderr.fileHandleForReading.close()
        }

        func send(_ request: [String: Any]) -> Bool {
            guard var data = try? JSONSerialization.data(withJSONObject: request) else { return false }
            data.append(0x0A)   // newline-delimited JSON-RPC
            return (try? stdin.fileHandleForWriting.write(contentsOf: data)) != nil
        }

        guard send([
            "jsonrpc": "2.0", "id": 1, "method": "initialize",
            "params": [
                "protocolVersion": 1,
                "clientCapabilities": ["fs": ["readTextFile": false, "writeTextFile": false]]
            ]
        ]), send([
            "jsonrpc": "2.0", "id": 2, "method": "_x.ai/billing", "params": [:]
        ]) else {
            return .failure(.protocolFailure("could not write to the CLI"))
        }

        // The agent interleaves notifications with replies, so lines are read
        // until the one carrying id 2 arrives rather than assuming a position.
        let deadline = Date().addingTimeInterval(timeout)
        var buffer = Data()
        let handle = stdout.fileHandleForReading

        while Date() < deadline {
            let chunk = handle.availableData
            if chunk.isEmpty {
                // EOF: the CLI exited without answering. Its stderr says why —
                // most often that it isn't signed in.
                let message = String(data: stderr.fileHandleForReading.availableData, encoding: .utf8) ?? ""
                return .failure(Self.error(fromStderr: message))
            }
            buffer.append(chunk)

            while let newline = buffer.firstIndex(of: 0x0A) {
                let line = buffer[buffer.startIndex..<newline]
                buffer = buffer[buffer.index(after: newline)...]

                guard let message = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                      message["id"] as? Int == 2 else {
                    continue
                }
                if let error = message["error"] as? [String: Any] {
                    let text = error["message"] as? String ?? "request rejected"
                    return .failure(.protocolFailure(text))
                }
                guard let result = message["result"] as? [String: Any],
                      let usage = parse(result) else {
                    return .failure(.protocolFailure("billing reply had no usage figure"))
                }
                return .success(usage)
            }
        }
        return .failure(.timedOut)
    }

    /// Turns the `_x.ai/billing` result into a snapshot.
    ///
    /// Lenient in the same way the Claude parsing is: only the percentage is
    /// required, so a renamed period field costs the reset time rather than the
    /// whole row.
    private static func parse(_ result: [String: Any]) -> GrokUsage? {
        let config = result["config"] as? [String: Any] ?? [:]
        guard let used = config["creditUsagePercent"] as? Double else { return nil }

        let period = config["currentPeriod"] as? [String: Any]
        let kind = (period?["type"] as? String)?
            .replacingOccurrences(of: "USAGE_PERIOD_TYPE_", with: "")

        return GrokUsage(
            usedPercent: used,
            periodStart: date(from: period?["start"] as? String ?? config["billingPeriodStart"] as? String),
            periodEnd: date(from: period?["end"] as? String ?? config["billingPeriodEnd"] as? String),
            periodKind: kind,
            tier: result["subscription_tier"] as? String,
            fetchedAt: Date()
        )
    }

    /// The timestamps carry fractional seconds; `withInternetDateTime` alone
    /// rejects those, so both shapes are tried.
    private static func date(from string: String?) -> Date? {
        guard let string = string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private static func error(fromStderr message: String) -> GrokError {
        let lowered = message.lowercased()
        if lowered.contains("login") || lowered.contains("auth") || lowered.contains("sign in") {
            return .notSignedIn
        }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return .protocolFailure(trimmed.isEmpty ? "the CLI exited without answering" : String(trimmed.prefix(200)))
    }
}
