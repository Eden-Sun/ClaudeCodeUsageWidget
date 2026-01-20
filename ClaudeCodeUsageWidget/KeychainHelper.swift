import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()
    private let service = "com.claudecode.usagewidget"
    private let account = "claude_api_key"
    
    private init() {}
    
    // Save API key to Keychain
    func saveAPIKey(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else {
            return false
        }
        
        // Delete any existing item
        deleteAPIKey()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // Retrieve API key from Keychain
    func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return key
    }
    
    // Delete API key from Keychain
    func deleteAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // Check if API key exists
    func hasAPIKey() -> Bool {
        return getAPIKey() != nil
    }
}

// Extension to migrate from UserDefaults to Keychain
extension KeychainHelper {
    func migrateFromUserDefaults() {
        // Check if we have an old API key in UserDefaults
        if let oldKey = UserDefaults.standard.string(forKey: "claude_api_key"),
           !oldKey.isEmpty,
           !hasAPIKey() {
            // Migrate to Keychain
            if saveAPIKey(oldKey) {
                // Remove from UserDefaults after successful migration
                UserDefaults.standard.removeObject(forKey: "claude_api_key")
                print("Successfully migrated API key to Keychain")
            }
        }
    }
}
