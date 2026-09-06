import Foundation
import Security
import CryptoKit

/// One Claude Code profile: a config directory and the Keychain slot that
/// holds its OAuth credentials.
struct ClaudeAccount: Identifiable, Equatable {
    /// Keychain service name, e.g. "Claude Code-credentials-81129bfc".
    let service: String
    /// Human label derived from the config directory, e.g. "default", "ccompany".
    let label: String
    /// Config directory path, when it could be resolved.
    let configDir: String?

    var id: String { service }

    /// The command that logs this profile back in.
    ///
    /// The unresolved case matters: `configDirsByHash()` only scans `~/.claude*`,
    /// so a profile whose CLAUDE_CONFIG_DIR lives anywhere else is known by its
    /// service hash alone. Falling back to `claude login` there would send the
    /// user to re-authenticate ~/.claude — a different profile — and leave this
    /// one just as broken, so the directory stays an explicit placeholder.
    var loginHint: String {
        if isDefault { return "claude login" }
        guard let configDir = configDir else { return "CLAUDE_CONFIG_DIR=<dir for \(label)> claude" }
        return "CLAUDE_CONFIG_DIR=\(configDir.replacingOccurrences(of: NSHomeDirectory(), with: "~")) claude"
    }

    var isDefault: Bool { service == KeychainHelper.defaultService }
}

/// OAuth credentials as written by the Claude Code CLI.
///
/// Note: the stored blob also carries a `subscriptionType`, but it goes stale
/// after a plan change — the plan is read from the profile endpoint instead.
struct ClaudeCodeCredentials {
    let accessToken: String
    let expiresAt: Date?
    let refreshToken: String?
    let refreshTokenExpiresAt: Date?
    /// The Keychain account attribute this blob was read from — needed to write
    /// a refreshed token back to the same item.
    let keychainAccount: String
    /// The whole stored blob. A refresh rewrites it in place so the fields the
    /// CLI owns (scopes, subscriptionType, …) survive untouched.
    let raw: [String: Any]

    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return expiresAt <= Date()
    }

    /// Whether a refresh is worth attempting. The refresh token lives far
    /// longer than the access token (weeks vs. hours), so an idle profile is
    /// almost always recoverable without a re-login.
    var canRefresh: Bool {
        guard let refreshToken = refreshToken, !refreshToken.isEmpty else { return false }
        if let expiry = refreshTokenExpiresAt, expiry <= Date() { return false }
        return true
    }
}

/// Outcome of a token refresh. `notSaved` is kept apart from `failed` because
/// the two need different things from the user: a failure is transient and the
/// next poll retries it, while an unsaved renewal has already retired the
/// stored refresh token and only a re-login fixes it.
enum RefreshResult {
    case renewed(ClaudeCodeCredentials)
    case failed
    case notSaved
}

class KeychainHelper {
    static let shared = KeychainHelper()

    /// Claude Code keys its credentials by config directory. The default
    /// (~/.claude) uses the bare service name; any other CLAUDE_CONFIG_DIR gets
    /// `-<first 8 hex of sha256(absolute path)>` appended.
    static let defaultService = "Claude Code-credentials"
    private static let servicePrefix = "Claude Code-credentials"

    /// Guards `pendingRefreshes`.
    private let refreshLock = NSLock()
    /// Callbacks waiting on an in-flight refresh, keyed by service.
    private var pendingRefreshes: [String: [(RefreshResult) -> Void]] = [:]

    /// Guards `cache`.
    private let cacheLock = NSLock()
    /// The last blob read out of each slot, with the item's modification date at
    /// the time it was read, keyed by service.
    ///
    /// This exists for the *prompt*, not for speed. Reading the payload is what
    /// raises "wants to use your confidential information", and the app polls
    /// every five minutes: on a build whose signature isn't in the item's ACL —
    /// any ad-hoc signed build, since its designated requirement is the binary's
    /// cdhash — an uncached read means that dialog every five minutes, forever.
    /// Holding the blob in memory turns that into at most one prompt per launch.
    ///
    /// The modification date is what keeps that from going stale. Expiry alone
    /// is not enough: `claude login` swaps the *identity* in a slot without
    /// touching when the token expires, and the token it replaces usually stays
    /// valid, so nothing 401s and nothing else would notice. The app would keep
    /// reporting the previous account for hours.
    private var cache: [String: (credentials: ClaudeCodeCredentials, modified: Date?)] = [:]

    /// How long before a cached access token's expiry it stops being served.
    /// The margin covers the round trip that's about to use it.
    private static let cacheMargin: TimeInterval = 60

    private init() {}

    // MARK: - Discovery

    /// Every Claude Code profile with credentials on this machine.
    ///
    /// Only Keychain *attributes* are read here, never the secret payload, so
    /// this never raises an access prompt — the prompt comes later, once per
    /// slot, when a token is actually read.
    func discoverAccounts() -> [ClaudeAccount] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }

        let services = Set(
            items.compactMap { $0[kSecAttrService as String] as? String }
                 .filter { $0.hasPrefix(Self.servicePrefix) }
        )

        // When each profile was first logged in, which is what the display is
        // ordered by. Taken from the attributes already in hand, so it costs
        // nothing. A service with several accounts under it takes the earliest.
        var createdAt: [String: Date] = [:]
        for item in items {
            guard let service = item[kSecAttrService as String] as? String,
                  let created = item[kSecAttrCreationDate as String] as? Date else { continue }
            createdAt[service] = min(createdAt[service] ?? created, created)
        }

        let byHash = configDirsByHash()

        return services.map { service in
            if service == Self.defaultService {
                let path = NSHomeDirectory() + "/.claude"
                return ClaudeAccount(service: service, label: "default", configDir: path)
            }
            let hash = String(service.dropFirst(Self.servicePrefix.count + 1)) // strip "-"
            let dir = byHash[hash]
            return ClaudeAccount(
                service: service,
                label: dir.map(Self.label(forConfigDir:)) ?? hash,
                configDir: dir
            )
        }
        // Oldest login first.
        //
        // Alphabetical was the obvious choice and the wrong one: it sorted
        // "cc2" ahead of "ccompany" on the third character, so adding a profile
        // reshuffled the ones already on screen into an order that matched
        // nothing the user knew. Login order is what they actually remember,
        // and it only ever appends — a new profile lands at the end and leaves
        // every existing position alone.
        //
        // `claude login` on an existing profile rewrites the item in place and
        // leaves its creation date untouched, so re-authenticating does not
        // move a profile. A full logout and back in does, since that is a new
        // item; the label breaks ties so a slot with no date left is still
        // ordered predictably.
        .sorted {
            let left = createdAt[$0.service] ?? .distantFuture
            let right = createdAt[$1.service] ?? .distantFuture
            return left == right ? $0.label < $1.label : left < right
        }
    }

    /// Maps `sha256(configDir)[0..<8]` to the directory, by hashing every
    /// `~/.claude*` directory. Slots whose directory has been deleted stay
    /// unresolved and fall back to showing the raw hash.
    private func configDirsByHash() -> [String: String] {
        let home = NSHomeDirectory()
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: home) else {
            return [:]
        }

        var map: [String: String] = [:]
        for entry in entries where entry.hasPrefix(".claude") {
            let path = home + "/" + entry
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }

            let digest = SHA256.hash(data: Data(path.utf8))
            let hex = digest.map { String(format: "%02x", $0) }.joined()
            map[String(hex.prefix(8))] = path
        }
        return map
    }

    /// "/Users/me/.claude-ccompany" -> "ccompany", "/Users/me/.claude" -> "default"
    private static func label(forConfigDir path: String) -> String {
        let name = (path as NSString).lastPathComponent
        if name == ".claude" { return "default" }
        if name.hasPrefix(".claude-") { return String(name.dropFirst(".claude-".count)) }
        return name
    }

    // MARK: - Credentials

    /// Reads the OAuth blob out of one Keychain slot.
    ///
    /// Two steps on purpose. The account attribute is written by the CLI and is
    /// not necessarily the local `NSUserName()`, so the accounts under the
    /// service are enumerated first — attributes alone, which never needs
    /// authorization. The payload is then read one account at a time with
    /// `kSecMatchLimitOne`: asking for `kSecReturnData` under
    /// `kSecMatchLimitAll` makes the Keychain skip anything that would require
    /// authorization instead of putting up the "wants to use your confidential
    /// information" prompt, which left the app with no token at all after a
    /// rebuild changed its signature.
    func credentials(for service: String) -> ClaudeCodeCredentials? {
        if let cached = cachedCredentials(for: service) { return cached }

        for account in accounts(for: service) {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]

            var result: AnyObject?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                  let data = result as? Data,
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let oauth = root["claudeAiOauth"] as? [String: Any],
                  let token = oauth["accessToken"] as? String,
                  !token.isEmpty else {
                continue
            }

            let credentials = ClaudeCodeCredentials(
                accessToken: token,
                expiresAt: Self.date(fromMilliseconds: oauth["expiresAt"]),
                refreshToken: oauth["refreshToken"] as? String,
                refreshTokenExpiresAt: Self.date(fromMilliseconds: oauth["refreshTokenExpiresAt"]),
                keychainAccount: account,
                raw: root
            )
            remember(credentials, for: service)
            return credentials
        }

        return nil
    }

    /// The cached blob for one slot, if it's still good for a request.
    ///
    /// A cached token is served only while it has `cacheMargin` of life left.
    /// Once it doesn't, the cache is skipped so the Keychain is re-read — which
    /// is how a token the CLI renewed in the background gets picked up, the
    /// property the uncached read used to provide. A blob with no recorded
    /// expiry is never cached at all (see `remember`), so this can't pin one
    /// forever.
    private func cachedCredentials(for service: String) -> ClaudeCodeCredentials? {
        // Outside the lock: this is a Keychain round trip, and it only reads
        // attributes, so it never blocks on a prompt.
        let modified = modificationDate(for: service)

        cacheLock.lock()
        defer { cacheLock.unlock() }
        guard let cached = cache[service], let expiry = cached.credentials.expiresAt else { return nil }

        // The slot was rewritten since this blob was read — a login, a logout,
        // or a refresh by the CLI. Whatever it was, what's cached is not what's
        // stored any more.
        guard cached.modified == modified else {
            cache[service] = nil
            return nil
        }
        guard expiry.timeIntervalSinceNow > Self.cacheMargin else {
            cache[service] = nil
            return nil
        }
        return cached.credentials
    }

    private func remember(_ credentials: ClaudeCodeCredentials, for service: String) {
        guard credentials.expiresAt != nil else { return }
        // Read after the payload, so a write that lands between the two shows up
        // as a mismatch on the next poll rather than being cached over.
        let modified = modificationDate(for: service)
        cacheLock.lock()
        cache[service] = (credentials, modified)
        cacheLock.unlock()
    }

    /// When the slot was last written, across every account stored under it.
    ///
    /// Attributes only, so this never raises an access prompt — which is what
    /// makes it usable as a cheap freshness check on every poll. A slot with no
    /// items returns nil, and nil never equals a real date, so a cache entry for
    /// a slot that has since been deleted is discarded rather than served.
    private func modificationDate(for service: String) -> Date? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return nil
        }
        return items.compactMap { $0[kSecAttrModificationDate as String] as? Date }.max()
    }

    /// Drops one slot's cached blob so the next read goes back to the Keychain.
    ///
    /// Needed because an access token can stop working before its recorded
    /// expiry — a revoked session, or a re-login that rotated it out from under
    /// us. Without this a cached-but-rejected token would be re-sent until it
    /// expired on paper.
    func invalidateCache(for service: String) {
        cacheLock.lock()
        cache[service] = nil
        cacheLock.unlock()
    }

    /// Account attributes stored under one service, local username first so the
    /// common case costs a single read.
    private func accounts(for service: String) -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return [NSUserName()]
        }

        let names = items.compactMap { $0[kSecAttrAccount as String] as? String }
        guard !names.isEmpty else { return [NSUserName()] }

        // Partition rather than sort: "is the local user" is not an ordering,
        // and feeding it to `sorted` is undefined behaviour for more than two
        // elements. The rest keep the order the Keychain returned them in.
        let local = NSUserName()
        return names.filter { $0 == local } + names.filter { $0 != local }
    }

    /// Timestamps in the stored blob are milliseconds since epoch.
    private static func date(fromMilliseconds value: Any?) -> Date? {
        guard let ms = value as? Double else { return nil }
        return Date(timeIntervalSince1970: ms / 1000.0)
    }

    // MARK: - Refresh

    /// The OAuth client the Claude Code CLI itself authenticates as. The token
    /// endpoint lives on api.anthropic.com; the console.anthropic.com host
    /// answers too but rate-limits aggressively.
    private static let tokenEndpoint = URL(string: "https://api.anthropic.com/v1/oauth/token")!
    private static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"

    /// Exchanges the stored refresh token for a fresh access token and writes
    /// the result back to the same Keychain item.
    ///
    /// The CLI only refreshes while it is running, so a profile you haven't
    /// used for a few hours sits on an expired access token indefinitely. Doing
    /// the exchange here keeps such a profile readable.
    ///
    /// The exchange necessarily happens before the write, and it rotates the
    /// refresh token server-side: by the time the Keychain write can fail, the
    /// token the CLI still holds has already been retired. Nothing here can
    /// undo that, so the case is reported as `.notSaved` instead of being folded
    /// into `.failed` — the app turns it into "run `claude login`", which is the
    /// only thing that actually recovers the profile.
    func refresh(_ credentials: ClaudeCodeCredentials,
                 service: String,
                 completion: @escaping (RefreshResult) -> Void) {
        guard credentials.canRefresh, let refreshToken = credentials.refreshToken else {
            completion(.failed)
            return
        }

        // The blob being refreshed may itself have come from the cache. Drop it
        // now: the exchange rotates the refresh token server-side, so a second
        // caller handed the same stale blob would present a retired token.
        invalidateCache(for: service)

        // One refresh per profile at a time — the poll timer and a popover-driven
        // refresh can otherwise rotate the token twice and invalidate the first
        // result.
        refreshLock.lock()
        if var waiters = pendingRefreshes[service] {
            waiters.append(completion)
            pendingRefreshes[service] = waiters
            refreshLock.unlock()
            return
        }
        pendingRefreshes[service] = [completion]
        refreshLock.unlock()

        let finish: (RefreshResult) -> Void = { [weak self] result in
            guard let self = self else { return }
            self.refreshLock.lock()
            let waiters = self.pendingRefreshes.removeValue(forKey: service) ?? []
            self.refreshLock.unlock()
            waiters.forEach { $0(result) }
        }

        var request = URLRequest(url: Self.tokenEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": Self.clientID
        ])

        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            guard let self = self,
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let data = data,
                  let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = body["access_token"] as? String,
                  !accessToken.isEmpty else {
                finish(.failed)
                return
            }

            var oauth = credentials.raw["claudeAiOauth"] as? [String: Any] ?? [:]
            oauth["accessToken"] = accessToken
            if let rotated = body["refresh_token"] as? String, !rotated.isEmpty {
                oauth["refreshToken"] = rotated
            }
            if let lifetime = body["expires_in"] as? Double {
                oauth["expiresAt"] = Date().addingTimeInterval(lifetime).timeIntervalSince1970 * 1000
            }
            var root = credentials.raw
            root["claudeAiOauth"] = oauth

            guard self.store(root, service: service, account: credentials.keychainAccount) else {
                finish(.notSaved)
                return
            }

            let renewed = ClaudeCodeCredentials(
                accessToken: accessToken,
                expiresAt: Self.date(fromMilliseconds: oauth["expiresAt"]),
                refreshToken: oauth["refreshToken"] as? String,
                refreshTokenExpiresAt: credentials.refreshTokenExpiresAt,
                keychainAccount: credentials.keychainAccount,
                raw: root
            )
            self.remember(renewed, for: service)
            finish(.renewed(renewed))
        }.resume()
    }

    /// Overwrites one Keychain item's payload in place, leaving its access
    /// control and attributes as the CLI set them.
    private func store(_ root: [String: Any], service: String, account: String) -> Bool {
        guard let data = try? JSONSerialization.data(withJSONObject: root) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        return SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecSuccess
    }
}
