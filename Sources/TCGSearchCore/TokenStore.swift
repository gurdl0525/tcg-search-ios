import Foundation
import Security

protocol TokenStore {
    func load() throws -> TokenPair?

    func save(_ tokenPair: TokenPair) throws

    func clear() throws
}

final class KeychainTokenStore: TokenStore {
    private let service: String
    private let account: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        service: String = "com.tcgsearch.ios.auth",
        account: String = "token-pair",
    ) {
        self.service = service
        self.account = account
    }

    func load() throws -> TokenPair? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw TokenStoreError.keychain(status)
        }

        guard let data = item as? Data else {
            throw TokenStoreError.invalidData
        }

        return try decoder.decode(TokenPair.self, from: data)
    }

    func save(_ tokenPair: TokenPair) throws {
        let data = try encoder.encode(tokenPair)
        var item = baseQuery
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(item as CFDictionary, nil)

        if status == errSecDuplicateItem {
            try update(data)
            return
        }

        guard status == errSecSuccess else {
            throw TokenStoreError.keychain(status)
        }
    }

    func clear() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw TokenStoreError.keychain(status)
        }
    }

    private func update(_ data: Data) throws {
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)

        guard status == errSecSuccess else {
            throw TokenStoreError.keychain(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

enum TokenStoreError: Error, Equatable {
    case invalidData
    case keychain(OSStatus)
}
