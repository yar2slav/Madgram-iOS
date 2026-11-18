import Foundation
import Security
import CryptoKit

public enum MadLockKind: String, Codable, CaseIterable {
    case pin
    case password
    case pattern
}

struct MadLockStoredCredential: Codable {
    var kind: MadLockKind
    var length: Int
    var salt: Data
    var hash: Data
    var biometrics: Bool
}

enum MadLockCredentialStore {
    private static let service = "org.madgram.lock"
    private static let account = "credential"

    static func load() -> MadLockStoredCredential? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(MadLockStoredCredential.self, from: data)
    }

    static func store(_ credential: MadLockStoredCredential?) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        guard let credential, let data = try? JSONEncoder().encode(credential) else {
            return
        }
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func hash(_ secret: String, salt: Data) -> Data {
        var input = salt
        input.append(Data(secret.utf8))
        return Data(SHA256.hash(data: input))
    }

    static func makeCredential(kind: MadLockKind, secret: String, biometrics: Bool) -> MadLockStoredCredential {
        var salt = Data(count: 16)
        salt.withUnsafeMutableBytes { bytes in
            if let base = bytes.baseAddress {
                _ = SecRandomCopyBytes(kSecRandomDefault, 16, base)
            }
        }
        return MadLockStoredCredential(kind: kind, length: secret.count, salt: salt, hash: hash(secret, salt: salt), biometrics: biometrics)
    }

    private static let failuresKey = "madgram.lock.failures"
    private static let blockedUntilKey = "madgram.lock.blockedUntil"
    private static let lastFailureKey = "madgram.lock.lastFailure"

    static var blockedFor: TimeInterval {
        let defaults = UserDefaults.standard
        let now = Date().timeIntervalSince1970
        let until = defaults.double(forKey: blockedUntilKey)
        guard until > 0 else {
            return 0.0
        }
        if now < defaults.double(forKey: lastFailureKey) {
            return until - defaults.double(forKey: lastFailureKey)
        }
        return max(0.0, until - now)
    }

    static func registerFailure() {
        let defaults = UserDefaults.standard
        let failures = defaults.integer(forKey: failuresKey) + 1
        let now = Date().timeIntervalSince1970
        defaults.set(failures, forKey: failuresKey)
        defaults.set(now, forKey: lastFailureKey)
        if failures >= 5 {
            defaults.set(now + min(3600.0, 30.0 * pow(2.0, Double(failures - 5))), forKey: blockedUntilKey)
        }
    }

    static func resetFailures() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: failuresKey)
        defaults.removeObject(forKey: blockedUntilKey)
        defaults.removeObject(forKey: lastFailureKey)
    }

    static func verify(_ secret: String) -> Bool {
        guard let credential = load() else {
            return false
        }
        return hash(secret, salt: credential.salt) == credential.hash
    }
}
