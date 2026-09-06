import Foundation
import CryptoKit
import os.log

// MARK: - Model

/// One rolling usage window (the 5-hour session window, or the weekly cap).
struct UsageWindow {
    let utilization: Double   // percent consumed, 0...100
    let resetsAt: Date?

    var percent: Int { Int(utilization.rounded()) }

    /// The API reports consumption; the UI shows headroom.
    var remainingPercent: Int { max(0, 100 - percent) }

    /// True once the reset time has passed. A snapshot kept on screen after
    /// the token lapsed still carries the old figure, which by then describes
    /// a window that has already rolled over.
    var hasReset: Bool {
        guard let resetsAt = resetsAt else { return false }
        return resetsAt <= Date()
    }
}

/// An entry from the `limits` array. Richer than the top-level windows: carries
/// a severity and, for `weekly_scoped`, which model the cap applies to.
struct UsageLimit: Identifiable {
    let kind: String        // "session" | "weekly_all" | "weekly_scoped" | ...
    let group: String       // "session" | "weekly" | ...
    let percent: Int        // consumed
    let severity: String    // "normal" | ... (server-defined, treated as opaque)
    let resetsAt: Date?
    let scopeLabel: String? // e.g. "Fable", "Opus"
    let isActive: Bool

    var id: String { "\(kind)-\(scopeLabel ?? "all")" }

    var remainingPercent: Int { max(0, 100 - percent) }

    var hasReset: Bool {
        guard let resetsAt = resetsAt else { return false }
        return resetsAt <= Date()
    }

    var displayName: String {
        if let scope = scopeLabel { return "Weekly · \(scope)" }
        switch kind {
        case "session": return "Session (5h)"
        case "weekly_all": return "Weekly"
        default: return kind.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

struct UsageSnapshot {
    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?
    let limits: [UsageLimit]
    let fetchedAt: Date

    /// What the menu bar leads with — the window most likely to bite first.
    var headline: UsageWindow? { fiveHour ?? sevenDay }

    /// nil when the response carried no usable window — the UI must show that
    /// as "--", not as a confident 0%.
    var headlineRemaining: Int? { headline?.remainingPercent }

    /// Scoped per-model weekly caps, which the top-level fields don't expose.
    var scopedLimits: [UsageLimit] { limits.filter { $0.scopeLabel != nil } }

    /// The Fable weekly cap, when the account has one. Matched on the label
    /// rather than a model id — the API sends `scope.model.id` as null.
    var fableLimit: UsageLimit? {
        scopedLimits.first { $0.scopeLabel?.localizedCaseInsensitiveContains("fable") == true }
    }
}

/// Identity of the signed-in account, from the profile endpoint.
struct ProfileInfo {
    let planLabel: String?
    let email: String?
}

/// Everything known about one profile after a poll.
struct AccountUsage: Identifiable {
    let account: ClaudeAccount
    var snapshot: UsageSnapshot?
    var profile: ProfileInfo?
    var error: UsageError?

    var planLabel: String? { profile?.planLabel }
    var email: String? { profile?.email }

    var id: String { account.service }

    /// The token could not be used on this poll but a previous snapshot is
    /// still on screen — the numbers are real, just not current.
    var isStale: Bool { snapshot != nil && error != nil }

    /// Nothing to show at all.
    var isSignedOut: Bool { snapshot == nil }

    var isMaxPlan: Bool? {
        guard let planLabel = planLabel else { return nil }
        return planLabel.hasPrefix("Max")
    }
}

enum UsageError: LocalizedError, Equatable {
    case noAccounts
    case noCredentials
    case expiredCredentials
    case refreshFailed
    case renewalNotSaved
    case unauthorized
    case http(Int)
    case network(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .noAccounts:
            return "No Claude Code login found.\nRun `claude login` in a terminal."
        case .noCredentials:
            return "Credentials unreadable — Keychain access may have been denied."
        case .expiredCredentials:
            return "Session expired."
        case .refreshFailed:
            return "Session expired and could not be renewed."
        case .renewalNotSaved:
            return "Session renewed but the new token could not be saved.\nRun `claude login` in a terminal."
        case .unauthorized:
            return "Token rejected (401)."
        case .http(let code):
            return "Usage API returned HTTP \(code)."
        case .network(let message):
            return "Network error: \(message)"
        case .decoding(let message):
            return "Unexpected response: \(message)"
        }
    }
}

// MARK: - Monitor

class UsageMonitor: ObservableObject {
    /// One entry per discovered Claude Code profile, default profile first.
    @Published var accounts: [AccountUsage] = []
    @Published var isLoading = false
    /// Set only when nothing at all could be polled.
    @Published var error: String?

    /// Which profile drives the menu bar. Persisted so the choice survives
    /// relaunches; falls back to the default profile.
    @Published var primaryService: String = UserDefaults.standard.string(forKey: primaryServiceKey)
        ?? KeychainHelper.defaultService {
        didSet {
            UserDefaults.standard.set(primaryService, forKey: Self.primaryServiceKey)
            onUsageUpdate?()
        }
    }

    /// How much of each reading the menu bar shows. Persisted, and pushed
    /// through the same update path as the primary profile so a change is
    /// visible immediately rather than at the next poll.
    ///
    /// Automatic is right almost always; the override exists because the thing
    /// that squeezes this item is *other* apps' status items, whose widths this
    /// app cannot see. When the menu bar is crowded enough that macOS starts
    /// hiding items under the notch, only the user can tell.
    @Published var menuBarDetail: Int = UserDefaults.standard.object(forKey: menuBarDetailKey) as? Int ?? -1 {
        didSet {
            UserDefaults.standard.set(menuBarDetail, forKey: Self.menuBarDetailKey)
            onUsageUpdate?()
        }
    }

    private static let primaryServiceKey = "primary_account_service"
    private static let menuBarDetailKey = "menu_bar_detail"

    var primary: AccountUsage? {
        accounts.first { $0.account.service == primaryService } ?? accounts.first
    }

    /// Fires after every poll, including one that ends with no profiles at
    /// all — the menu bar has to be able to clear itself, so this deliberately
    /// carries no payload.
    var onUsageUpdate: (() -> Void)?

    /// Undocumented but stable endpoints that Claude Code itself calls. Note the
    /// host is api.anthropic.com — claude.ai sits behind Cloudflare and 403s.
    private let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private let profileEndpoint = URL(string: "https://api.anthropic.com/api/oauth/profile")!

    private var timer: Timer?
    private var isFetching = false
    private let updateInterval: TimeInterval = 300 // 5 minutes
    private let logger = Logger(subsystem: "com.claudecode.usagewidget", category: "UsageMonitor")

    /// Identity doesn't change between polls, so it is cached per profile
    /// rather than re-fetched every 5 minutes. The cache is stamped with a
    /// fingerprint of the token it was fetched with: logging a profile in as a
    /// different account issues a new token, which misses the cache and
    /// re-reads the identity. Keying on the service alone kept showing the
    /// previous account's email until the app was relaunched.
    private var profileCache: [String: (tokenFingerprint: String, info: ProfileInfo)] = [:]

    /// The last snapshot each profile returned successfully. A profile whose
    /// token lapsed keeps showing these numbers, marked stale, instead of
    /// blanking the column — the usage windows move slowly enough that an
    /// hour-old reading still tells you where you stand.
    private var lastGood: [String: (snapshot: UsageSnapshot, profile: ProfileInfo?)] = [:]

    /// Short digest of an access token — enough to notice it changed, without
    /// keeping a second copy of the token around.
    private static func fingerprint(_ token: String) -> String {
        SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func startMonitoring() {
        fetchUsage()
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.fetchUsage()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    /// Refetch unless *every* profile has a recent, error-free snapshot.
    /// Keying this off the primary alone meant a secondary profile stuck in an
    /// error state was never retried while the primary kept refreshing.
    func refreshIfStale(maxAge: TimeInterval = 30) {
        guard !accounts.isEmpty else {
            fetchUsage()
            return
        }
        let allFresh = accounts.allSatisfy { account in
            guard account.error == nil, let fetchedAt = account.snapshot?.fetchedAt else { return false }
            return Date().timeIntervalSince(fetchedAt) <= maxAge
        }
        if !allFresh { fetchUsage() }
    }

    func fetchUsage() {
        // Everything below reads or writes `profileCache`, `lastGood` and the
        // @Published state, so the whole poll is pinned to the main queue —
        // that, not a lock, is what keeps those dictionaries safe.
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.fetchUsage() }
            return
        }

        // The 5-minute timer and a manual refresh can otherwise run two batches
        // at once, and whichever finishes first clears `isLoading` while the
        // other is still in flight.
        guard !isFetching else { return }

        // Rediscover every poll — a profile can be added or logged out at any
        // time, and discovery only reads Keychain attributes, so it's cheap.
        let discovered = KeychainHelper.shared.discoverAccounts()
        guard !discovered.isEmpty else {
            isLoading = false
            accounts = []
            error = UsageError.noAccounts.errorDescription
            // Fires with an empty list on purpose: the menu bar is still
            // showing the last profile's numbers and has to clear them.
            onUsageUpdate?()
            return
        }

        isFetching = true
        isLoading = true
        error = nil

        let group = DispatchGroup()
        let lock = NSLock()
        var results: [String: AccountUsage] = [:]

        for account in discovered {
            group.enter()
            fetch(account) { result in
                lock.lock()
                results[account.service] = result
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.isFetching = false
            self.isLoading = false
            self.accounts = discovered.compactMap { results[$0.service] }
            self.error = nil
            self.onUsageUpdate?()
        }
    }

    // MARK: - Per-account fetch

    private func fetch(_ account: ClaudeAccount, completion: @escaping (AccountUsage) -> Void) {
        // `credentials(for:)` serves an in-memory blob while its access token
        // has life left and re-reads the Keychain once it doesn't, so a token
        // the CLI refreshed in the background is still picked up — without
        // paying a Keychain access prompt on every single poll.
        guard let credentials = KeychainHelper.shared.credentials(for: account.service) else {
            completion(degraded(account, .noCredentials))
            return
        }

        guard credentials.isExpired else {
            load(account, credentials: credentials, allowRefresh: true, completion: completion)
            return
        }

        // The CLI only renews a token while it is running, so a profile left
        // idle for a few hours is expired but perfectly recoverable — renew it
        // here rather than telling the user to go run `claude`.
        guard credentials.canRefresh else {
            completion(degraded(account, .expiredCredentials))
            return
        }
        // `refresh` calls back on the URLSession queue, and both `degraded` and
        // `load` read the caches — hop to main before either.
        KeychainHelper.shared.refresh(credentials, service: account.service) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .renewed(let renewed):
                    self.load(account, credentials: renewed, allowRefresh: false, completion: completion)
                case .notSaved:
                    completion(self.degraded(account, .renewalNotSaved))
                case .failed:
                    completion(self.degraded(account, .refreshFailed))
                }
            }
        }
    }

    /// Builds a result for a failed poll, carrying the profile's last good
    /// numbers forward so the column stays useful.
    private func degraded(_ account: ClaudeAccount, _ error: UsageError) -> AccountUsage {
        let previous = lastGood[account.service]
        return AccountUsage(account: account,
                            snapshot: previous?.snapshot,
                            profile: previous?.profile,
                            error: error)
    }

    /// Fetches usage and, when not already cached, identity for one profile.
    /// `allowRefresh` is cleared on the retry after a renewal so a token the
    /// server keeps rejecting can't loop.
    private func load(_ account: ClaudeAccount,
                      credentials: ClaudeCodeCredentials,
                      allowRefresh: Bool,
                      completion: @escaping (AccountUsage) -> Void) {
        let token = credentials.accessToken
        let fingerprint = Self.fingerprint(token)
        let group = DispatchGroup()

        // The two requests below run concurrently and write these, so every
        // access is guarded — the group's notify is the happens-before edge
        // that makes the final read safe.
        let lock = NSLock()
        var snapshot: UsageSnapshot?
        var failure: UsageError?
        var profile = profileCache[account.service]
            .flatMap { $0.tokenFingerprint == fingerprint ? $0.info : nil }

        group.enter()
        URLSession.shared.dataTask(with: authorized(endpoint, token: token)) { [weak self] data, response, error in
            defer { group.leave() }
            guard let self = self else { return }

            lock.lock()
            defer { lock.unlock() }

            if let error = error {
                failure = .network(error.localizedDescription)
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                failure = status == 401 ? .unauthorized : .http(status)
                return
            }
            guard let data = data else {
                failure = .decoding("empty response body")
                return
            }
            do {
                snapshot = try self.parse(data)
            } catch {
                failure = .decoding(error.localizedDescription)
            }
        }.resume()

        if profile == nil {
            group.enter()
            URLSession.shared.dataTask(with: authorized(profileEndpoint, token: token)) { data, response, _ in
                defer { group.leave() }
                guard (response as? HTTPURLResponse)?.statusCode == 200,
                      let data = data,
                      let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return
                }
                lock.lock()
                profile = Self.profileInfo(from: root)
                lock.unlock()
            }.resume()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }

            // A token can be rejected before its recorded expiry — a revoked
            // session, or a clock that disagrees with the server. Whatever the
            // cause, the blob this poll used is no longer usable, so drop it
            // from the credential cache: the token may have been rotated out by
            // a `claude login` elsewhere, and only a fresh Keychain read sees
            // that. Without this a rejected token would be re-sent until its
            // recorded expiry passed.
            if failure == .unauthorized {
                KeychainHelper.shared.invalidateCache(for: account.service)
            }

            // One renewal attempt covers the rejection without a re-login.
            if failure == .unauthorized, allowRefresh, credentials.canRefresh {
                KeychainHelper.shared.refresh(credentials, service: account.service) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .renewed(let renewed):
                            self.load(account, credentials: renewed, allowRefresh: false, completion: completion)
                        case .notSaved:
                            completion(self.degraded(account, .renewalNotSaved))
                        case .failed:
                            completion(self.degraded(account, .unauthorized))
                        }
                    }
                }
                return
            }

            if let profile = profile {
                self.profileCache[account.service] = (fingerprint, profile)
            }
            if let snapshot = snapshot {
                self.lastGood[account.service] = (snapshot, profile)
            }
            self.logger.info("\(account.label, privacy: .public): 5h \(snapshot?.fiveHour?.remainingPercent ?? -1, privacy: .public)% left")

            guard let snapshot = snapshot else {
                completion(self.degraded(account, failure ?? .decoding("no usage returned")))
                return
            }
            completion(AccountUsage(account: account,
                                    snapshot: snapshot,
                                    profile: profile,
                                    error: failure))
        }
    }

    private func authorized(_ url: URL, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    // MARK: - Plan

    static func profileInfo(from profile: [String: Any]) -> ProfileInfo {
        let account = profile["account"] as? [String: Any]
        return ProfileInfo(planLabel: planLabel(from: profile),
                           email: account?["email"] as? String)
    }

    static func planLabel(from profile: [String: Any]) -> String? {
        let account = profile["account"] as? [String: Any]
        let organization = profile["organization"] as? [String: Any]
        let tier = (organization?["rate_limit_tier"] as? String) ?? ""

        if account?["has_claude_max"] as? Bool == true {
            // e.g. "default_claude_max_5x" / "default_claude_max_20x"
            if let multiplier = tier.split(separator: "_").last, multiplier.hasSuffix("x"),
               multiplier.dropLast().allSatisfy(\.isNumber), multiplier.count > 1 {
                return "Max \(multiplier.dropLast())×"
            }
            return "Max"
        }
        if account?["has_claude_pro"] as? Bool == true { return "Pro" }
        if let type = organization?["organization_type"] as? String {
            return type.replacingOccurrences(of: "claude_", with: "").capitalized
        }
        return nil
    }

    // MARK: - Parsing

    /// Parsed leniently on purpose: this endpoint is undocumented, so a field
    /// that disappears or gains a sibling should degrade the display rather than
    /// fail the whole fetch.
    private func parse(_ data: Data) throws -> UsageSnapshot {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageError.decoding("response was not a JSON object")
        }

        let limits = (root["limits"] as? [[String: Any]] ?? []).compactMap(Self.parseLimit)
        let fiveHour = Self.parseWindow(root["five_hour"])
        let sevenDay = Self.parseWindow(root["seven_day"])

        // Leniency stops here: with no window and no limit there is nothing to
        // display, and treating that as a successful poll rendered it as a
        // confident "0% left" instead of an error.
        guard fiveHour != nil || sevenDay != nil || !limits.isEmpty else {
            throw UsageError.decoding("no usage windows in response")
        }

        return UsageSnapshot(
            fiveHour: fiveHour,
            sevenDay: sevenDay,
            limits: limits,
            fetchedAt: Date()
        )
    }

    private static func parseWindow(_ value: Any?) -> UsageWindow? {
        guard let dict = value as? [String: Any],
              let utilization = dict["utilization"] as? Double else {
            return nil
        }
        return UsageWindow(utilization: utilization, resetsAt: parseDate(dict["resets_at"]))
    }

    private static func parseLimit(_ dict: [String: Any]) -> UsageLimit? {
        guard let kind = dict["kind"] as? String,
              let percent = dict["percent"] as? Int else {
            return nil
        }

        // scope.model.display_name is the only human-readable label the API gives
        // for a per-model weekly cap.
        var scopeLabel: String?
        if let scope = dict["scope"] as? [String: Any],
           let model = scope["model"] as? [String: Any] {
            scopeLabel = model["display_name"] as? String
        }

        return UsageLimit(
            kind: kind,
            group: dict["group"] as? String ?? kind,
            percent: percent,
            severity: dict["severity"] as? String ?? "normal",
            resetsAt: parseDate(dict["resets_at"]),
            scopeLabel: scopeLabel,
            isActive: dict["is_active"] as? Bool ?? false
        )
    }

    /// The API sends 6-digit fractional seconds ("2026-08-12T05:10:00.633192+00:00"),
    /// which ISO8601DateFormatter only handles on some OS versions — so fall back
    /// to trimming the fraction rather than dropping the timestamp.
    private static let fractionalDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plainDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func parseDate(_ value: Any?) -> Date? {
        guard let string = value as? String else { return nil }

        if let date = fractionalDateFormatter.date(from: string) { return date }
        if let date = plainDateFormatter.date(from: string) { return date }
        let plain = plainDateFormatter

        // Strip ".123456" and retry.
        if let dot = string.firstIndex(of: "."),
           let offsetStart = string[dot...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) {
            let trimmed = string[string.startIndex..<dot] + string[offsetStart...]
            return plain.date(from: String(trimmed))
        }

        return nil
    }
}
