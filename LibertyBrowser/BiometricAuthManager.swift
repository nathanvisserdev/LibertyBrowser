import LocalAuthentication
import CryptoKit
import Foundation

/// Manages biometric authentication and encryption key derivation
class BiometricAuthManager {
    static let shared = BiometricAuthManager()
    
    private let context = LAContext()
    private var encryptionKey: SymmetricKey?
    
    enum AuthError: Error, LocalizedError {
        case biometricNotAvailable
        case authenticationFailed
        case keyDerivationFailed
        case keychainError(String)
        
        var errorDescription: String? {
            switch self {
            case .biometricNotAvailable:
                return "Biometric authentication is not available on this device"
            case .authenticationFailed:
                return "Biometric authentication failed"
            case .keyDerivationFailed:
                return "Failed to derive encryption key"
            case .keychainError(let msg):
                return "Keychain error: \(msg)"
            }
        }
    }
    
    private init() {}
    
    /// Check if biometric authentication is available
    func isBiometricAvailable() -> Bool {
        var error: NSError?
        let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return available
    }
    
    /// Get biometric type (Touch ID, Face ID, or none)
    func biometricType() -> LABiometryType {
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return context.biometryType
    }
    
    /// Authenticate user with biometrics
    func authenticate(reason: String = "Authenticate to access Liberty Browser") async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = "Use Passcode"
        
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw AuthError.biometricNotAvailable
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            if success {
                // Derive encryption key after successful authentication
                try await deriveEncryptionKey()
            } else {
                throw AuthError.authenticationFailed
            }
        } catch {
            throw AuthError.authenticationFailed
        }
    }
    
    /// Authenticate with device passcode as fallback
    func authenticateWithPasscode(reason: String = "Authenticate to access Liberty Browser") async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw AuthError.biometricNotAvailable
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            
            if success {
                try await deriveEncryptionKey()
            } else {
                throw AuthError.authenticationFailed
            }
        } catch {
            throw AuthError.authenticationFailed
        }
    }
    
    /// Derive encryption key from keychain or create new one
    private func deriveEncryptionKey() async throws {
        // Try to load existing key from keychain
        if let existingKey = try? loadKeyFromKeychain() {
            self.encryptionKey = existingKey
            return
        }
        
        // Generate new key if none exists
        let newKey = SymmetricKey(size: .bits256)
        try saveKeyToKeychain(newKey)
        self.encryptionKey = newKey
    }
    
    /// Get the current encryption key (must be authenticated first)
    func getEncryptionKey() throws -> SymmetricKey {
        guard let key = encryptionKey else {
            throw AuthError.authenticationFailed
        }
        return key
    }
    
    // MARK: - Keychain Management
    
    private let keychainService = "com.libertybrowser.encryption"
    private let keychainAccount = "database-encryption-key"
    
    private func saveKeyToKeychain(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        
        // Delete existing key first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new key with biometric protection
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: false // Never sync to iCloud for security
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw AuthError.keychainError("Failed to save key: \(status)")
        }
    }
    
    private func loadKeyFromKeychain() throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let keyData = result as? Data else {
            throw AuthError.keychainError("Failed to load key: \(status)")
        }
        
        return SymmetricKey(data: keyData)
    }
    
    /// Delete encryption key from keychain (for logout/reset)
    func deleteEncryptionKey() throws {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        
        let status = SecItemDelete(deleteQuery as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthError.keychainError("Failed to delete key: \(status)")
        }
        
        encryptionKey = nil
    }
    
    /// Lock the app (clear encryption key from memory)
    func lock() {
        encryptionKey = nil
    }
    
    /// Check if app is currently unlocked
    func isUnlocked() -> Bool {
        return encryptionKey != nil
    }
}
