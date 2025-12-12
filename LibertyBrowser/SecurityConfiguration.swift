import Foundation
import CryptoKit

/// Manages security configuration and policies
class SecurityConfiguration {
    static let shared = SecurityConfiguration()
    
    // Security policies
    struct Policies {
        var requireHTTPS: Bool = true
        var blockMixedContent: Bool = true
        var enableHSTS: Bool = true
        var certificatePinning: Bool = false
        var dnsOverHTTPS: Bool = true
        var blockThirdPartyCookies: Bool = true
        var minimumTLSVersion: TLSVersion = .tls13
        var allowedCipherSuites: [String] = [
            "TLS_AES_256_GCM_SHA384",
            "TLS_AES_128_GCM_SHA256",
            "TLS_CHACHA20_POLY1305_SHA256"
        ]
    }
    
    enum TLSVersion: String, CaseIterable {
        case tls12 = "TLS 1.2"
        case tls13 = "TLS 1.3"
    }
    
    private(set) var policies = Policies()
    
    // Known certificate pins (SHA-256 hashes of public keys)
    private var certificatePins: [String: [String]] = [:]
    
    // Known AI chatbot domains
    let aiChatbotDomains: Set<String> = [
        "openai.com",
        "chat.openai.com",
        "claude.ai",
        "chat.anthropic.com",
        "gemini.google.com",
        "bard.google.com",
        "copilot.microsoft.com",
        "bing.com",
        "character.ai",
        "poe.com",
        "perplexity.ai",
        "you.com",
        "phind.com"
    ]
    
    // DNS over HTTPS providers
    let dohProviders = [
        "Cloudflare": "https://cloudflare-dns.com/dns-query",
        "Google": "https://dns.google/dns-query",
        "Quad9": "https://dns.quad9.net/dns-query",
        "OpenDNS": "https://doh.opendns.com/dns-query"
    ]
    
    private init() {
        loadConfiguration()
    }
    
    // MARK: - Configuration Management
    
    func updatePolicies(_ newPolicies: Policies) {
        self.policies = newPolicies
        saveConfiguration()
    }
    
    func addCertificatePin(domain: String, publicKeyHash: String) {
        if certificatePins[domain] == nil {
            certificatePins[domain] = []
        }
        certificatePins[domain]?.append(publicKeyHash)
        saveConfiguration()
    }
    
    func getCertificatePins(for domain: String) -> [String]? {
        return certificatePins[domain]
    }
    
    // MARK: - Validation
    
    func validateURL(_ url: URL) -> ValidationResult {
        var issues: [String] = []
        
        // Check HTTPS requirement
        if policies.requireHTTPS && url.scheme != "https" {
            issues.append("Non-HTTPS connection not allowed")
        }
        
        // Check if domain is AI chatbot (for enhanced monitoring)
        let isAIChatbot = aiChatbotDomains.contains { domain in
            url.host?.contains(domain) ?? false
        }
        
        return ValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            requiresEnhancedMonitoring: isAIChatbot
        )
    }
    
    func validateTLSVersion(_ version: String) -> Bool {
        switch policies.minimumTLSVersion {
        case .tls13:
            return version.contains("1.3")
        case .tls12:
            return version.contains("1.2") || version.contains("1.3")
        }
    }
    
    func validateCipherSuite(_ cipher: String) -> Bool {
        return policies.allowedCipherSuites.contains { cipher.contains($0) }
    }
    
    // MARK: - Certificate Pinning
    
    func verifyCertificatePin(domain: String, publicKey: SecKey) -> Bool {
        guard policies.certificatePinning else { return true }
        guard let pins = certificatePins[domain], !pins.isEmpty else {
            // No pins configured, allow (or could be strict and deny)
            return true
        }
        
        // Calculate SHA-256 hash of public key
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return false
        }
        
        let hash = SHA256.hash(data: publicKeyData)
        let hashString = hash.map { String(format: "%02x", $0) }.joined()
        
        return pins.contains(hashString)
    }
    
    // MARK: - Persistence
    
    private func saveConfiguration() {
        let encoder = JSONEncoder()
        
        let config: [String: Any] = [
            "requireHTTPS": policies.requireHTTPS,
            "blockMixedContent": policies.blockMixedContent,
            "enableHSTS": policies.enableHSTS,
            "certificatePinning": policies.certificatePinning,
            "dnsOverHTTPS": policies.dnsOverHTTPS,
            "blockThirdPartyCookies": policies.blockThirdPartyCookies,
            "minimumTLSVersion": policies.minimumTLSVersion.rawValue,
            "allowedCipherSuites": policies.allowedCipherSuites,
            "certificatePins": certificatePins
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: config),
           let url = getConfigURL() {
            try? data.write(to: url)
        }
    }
    
    private func loadConfiguration() {
        guard let url = getConfigURL(),
              let data = try? Data(contentsOf: url),
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        // Load policies
        if let requireHTTPS = config["requireHTTPS"] as? Bool {
            policies.requireHTTPS = requireHTTPS
        }
        if let blockMixedContent = config["blockMixedContent"] as? Bool {
            policies.blockMixedContent = blockMixedContent
        }
        if let enableHSTS = config["enableHSTS"] as? Bool {
            policies.enableHSTS = enableHSTS
        }
        if let certificatePinning = config["certificatePinning"] as? Bool {
            policies.certificatePinning = certificatePinning
        }
        if let dnsOverHTTPS = config["dnsOverHTTPS"] as? Bool {
            policies.dnsOverHTTPS = dnsOverHTTPS
        }
        if let blockThirdPartyCookies = config["blockThirdPartyCookies"] as? Bool {
            policies.blockThirdPartyCookies = blockThirdPartyCookies
        }
        if let tlsVersionString = config["minimumTLSVersion"] as? String,
           let tlsVersion = TLSVersion(rawValue: tlsVersionString) {
            policies.minimumTLSVersion = tlsVersion
        }
        if let cipherSuites = config["allowedCipherSuites"] as? [String] {
            policies.allowedCipherSuites = cipherSuites
        }
        if let pins = config["certificatePins"] as? [String: [String]] {
            certificatePins = pins
        }
    }
    
    private func getConfigURL() -> URL? {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportPath = paths[0].appendingPathComponent("LibertyBrowser")
        try? FileManager.default.createDirectory(at: appSupportPath, withIntermediateDirectories: true)
        return appSupportPath.appendingPathComponent("security_config.json")
    }
    
    // MARK: - Export for Forensics
    
    func exportConfiguration() -> String {
        let config: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "policies": [
                "requireHTTPS": policies.requireHTTPS,
                "blockMixedContent": policies.blockMixedContent,
                "enableHSTS": policies.enableHSTS,
                "certificatePinning": policies.certificatePinning,
                "dnsOverHTTPS": policies.dnsOverHTTPS,
                "blockThirdPartyCookies": policies.blockThirdPartyCookies,
                "minimumTLSVersion": policies.minimumTLSVersion.rawValue,
                "allowedCipherSuites": policies.allowedCipherSuites
            ],
            "pinnedDomains": Array(certificatePins.keys),
            "version": "1.0.0"
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        
        return "{}"
    }
}

// MARK: - Data Structures

struct ValidationResult {
    let isValid: Bool
    let issues: [String]
    let requiresEnhancedMonitoring: Bool
}

// MARK: - Security Recommendations

extension SecurityConfiguration {
    
    /// Get security recommendations based on current configuration
    func getSecurityRecommendations() -> [SecurityRecommendation] {
        var recommendations: [SecurityRecommendation] = []
        
        if !policies.requireHTTPS {
            recommendations.append(SecurityRecommendation(
                severity: .high,
                title: "HTTPS Not Required",
                description: "Enable HTTPS-only mode to prevent unencrypted connections",
                action: "Enable 'Require HTTPS' in settings"
            ))
        }
        
        if !policies.dnsOverHTTPS {
            recommendations.append(SecurityRecommendation(
                severity: .medium,
                title: "DNS Not Encrypted",
                description: "DNS queries are not encrypted, allowing ISPs to see which sites you visit",
                action: "Enable 'DNS over HTTPS' in settings"
            ))
        }
        
        if policies.minimumTLSVersion == .tls12 {
            recommendations.append(SecurityRecommendation(
                severity: .medium,
                title: "Old TLS Version",
                description: "TLS 1.2 is older and less secure than TLS 1.3",
                action: "Set minimum TLS version to 1.3 in settings"
            ))
        }
        
        if !policies.certificatePinning && !certificatePins.isEmpty {
            recommendations.append(SecurityRecommendation(
                severity: .low,
                title: "Certificate Pinning Disabled",
                description: "You have configured certificate pins but pinning is disabled",
                action: "Enable certificate pinning in settings"
            ))
        }
        
        return recommendations
    }
}

struct SecurityRecommendation {
    enum Severity {
        case low, medium, high, critical
    }
    
    let severity: Severity
    let title: String
    let description: String
    let action: String
}
