import Foundation
#if canImport(Security)
import Security
#endif

protocol SecureStore {
    var apiToken: String? { get set }
}

final class KeychainSecureStore: SecureStore {
    private let service = "techhouse.app.securestore"
    private let account = "xf_api_token"

    var apiToken: String? {
        get { readValue(forKey: account) }
        set {
            if let newValue {
                save(newValue, forKey: account)
            } else {
                deleteValue(forKey: account)
            }
        }
    }

    private func save(_ value: String, forKey key: String) {
        #if canImport(Security)
        let data = value.data(using: .utf8) ?? Data()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
        #else
        UserDefaults.standard.set(value, forKey: key)
        #endif
    }

    private func readValue(forKey key: String) -> String? {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        SecItemCopyMatching(query as CFDictionary, &item)
        guard let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
        #else
        return UserDefaults.standard.string(forKey: key)
        #endif
    }

    private func deleteValue(forKey key: String) {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        #else
        UserDefaults.standard.removeObject(forKey: key)
        #endif
    }
}
