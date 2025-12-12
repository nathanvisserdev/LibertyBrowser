import Foundation

/// Detects and logs tampering attempts, especially on AI chatbot sites
class TamperDetectionSystem {
    static let shared = TamperDetectionSystem()
    
    // Known AI chatbot domains to monitor more closely
    private let aiChatbotDomains = [
        "openai.com",
        "chat.openai.com",
        "claude.ai",
        "chat.anthropic.com",
        "gemini.google.com",
        "bard.google.com",
        "copilot.microsoft.com",
        "bing.com/chat",
        "character.ai",
        "poe.com",
        "perplexity.ai"
    ]
    
    // Suspicious patterns that might indicate tampering
    private let suspiciousScriptPatterns = [
        "eval(",
        "Function(",
        "document.write(",
        "innerHTML =",
        ".appendChild",
        "createElement('script')",
        "src=\"data:",
        "javascript:",
        "onerror=",
        "onload="
    ]
    
    private let queue = DispatchQueue(label: "com.libertybrowser.tamperdetection", qos: .utility)
    
    private init() {}
    
    /// Check if domain is an AI chatbot site
    func isAIChatbotDomain(_ domain: String) -> Bool {
        return aiChatbotDomains.contains { domain.contains($0) }
    }
    
    /// Analyze and log tamper detection event
    func logTamperEvent(type: TamperEventType, domain: String, evidence: [String: Any], severity: TamperSeverity) {
        queue.async {
            let detection = TamperDetection(
                timestamp: Date().timeIntervalSince1970,
                domain: domain,
                detectionType: type.rawValue,
                evidence: self.dictionaryToJSON(evidence),
                severity: severity.rawValue,
                userAgentModified: type == .userAgentAccess,
                headerInjectionDetected: type == .headerInjection,
                domManipulationDetected: type == .domManipulation,
                scriptInjectionDetected: type == .scriptInjection
            )
            
            do {
                try EncryptedDatabase.shared.logTamperDetection(detection)
                
                // Also log to console for debugging
                print("🚨 TAMPER DETECTED: [\(severity.rawValue.uppercased())] \(type.rawValue) on \(domain)")
                print("   Evidence: \(evidence)")
            } catch {
                print("Failed to log tamper detection: \(error)")
            }
        }
    }
    
    /// Analyze script content for suspicious patterns
    func analyzeScriptContent(_ content: String, domain: String) {
        var suspiciousPatterns: [String] = []
        
        for pattern in suspiciousScriptPatterns {
            if content.contains(pattern) {
                suspiciousPatterns.append(pattern)
            }
        }
        
        if !suspiciousPatterns.isEmpty {
            let severity: TamperSeverity = isAIChatbotDomain(domain) ? .high : .medium
            
            logTamperEvent(
                type: .scriptInjection,
                domain: domain,
                evidence: [
                    "patterns": suspiciousPatterns,
                    "scriptLength": content.count,
                    "timestamp": Date().timeIntervalSince1970
                ],
                severity: severity
            )
        }
    }
    
    /// Monitor for header injection attempts
    func detectHeaderInjection(headers: [String: String], domain: String) {
        var suspiciousHeaders: [String: String] = [:]
        
        // Check for suspicious header values
        for (key, value) in headers {
            // Check for CRLF injection
            if value.contains("\r") || value.contains("\n") {
                suspiciousHeaders[key] = value
            }
            
            // Check for script injection in headers
            if value.contains("<script") || value.contains("javascript:") {
                suspiciousHeaders[key] = value
            }
        }
        
        if !suspiciousHeaders.isEmpty {
            logTamperEvent(
                type: .headerInjection,
                domain: domain,
                evidence: ["headers": suspiciousHeaders],
                severity: .high
            )
        }
    }
    
    /// Detect man-in-the-middle attacks
    func detectMITM(expectedCertHash: String?, actualCertHash: String, domain: String) {
        guard let expected = expectedCertHash else { return }
        
        if expected != actualCertHash {
            logTamperEvent(
                type: .certificateMismatch,
                domain: domain,
                evidence: [
                    "expected": expected,
                    "actual": actualCertHash,
                    "possibleMITM": true
                ],
                severity: .critical
            )
        }
    }
    
    /// Monitor for cookie tampering
    func detectCookieTampering(expectedCookies: [String: String], actualCookies: [String: String], domain: String) {
        var tamperedCookies: [String: [String: String]] = [:]
        
        for (name, expectedValue) in expectedCookies {
            if let actualValue = actualCookies[name], actualValue != expectedValue {
                tamperedCookies[name] = [
                    "expected": expectedValue,
                    "actual": actualValue
                ]
            }
        }
        
        if !tamperedCookies.isEmpty {
            let severity: TamperSeverity = isAIChatbotDomain(domain) ? .high : .medium
            
            logTamperEvent(
                type: .cookieTampering,
                domain: domain,
                evidence: ["cookies": tamperedCookies],
                severity: severity
            )
        }
    }
    
    /// Detect DNS spoofing
    func detectDNSSpoofing(domain: String, expectedIPs: [String], actualIPs: [String]) {
        let expectedSet = Set(expectedIPs)
        let actualSet = Set(actualIPs)
        
        if expectedSet != actualSet {
            logTamperEvent(
                type: .dnsSpoofing,
                domain: domain,
                evidence: [
                    "expected": expectedIPs,
                    "actual": actualIPs,
                    "difference": actualSet.subtracting(expectedSet)
                ],
                severity: .critical
            )
        }
    }
    
    /// Monitor for timing attacks (detecting if responses are artificially delayed)
    func detectTimingAnomaly(domain: String, expectedDuration: TimeInterval, actualDuration: TimeInterval) {
        let threshold = expectedDuration * 2.0 // 100% increase threshold
        
        if actualDuration > threshold {
            let severity: TamperSeverity = isAIChatbotDomain(domain) ? .medium : .low
            
            logTamperEvent(
                type: .timingAnomaly,
                domain: domain,
                evidence: [
                    "expected": expectedDuration,
                    "actual": actualDuration,
                    "threshold": threshold
                ],
                severity: severity
            )
        }
    }
    
    /// Generate forensic report for a domain
    func generateForensicReport(for domain: String, completion: @escaping (Result<ForensicReport, Error>) -> Void) {
        queue.async {
            // This would query the database for all tamper detection events for this domain
            // and compile them into a comprehensive forensic report
            
            let report = ForensicReport(
                domain: domain,
                reportGeneratedAt: Date(),
                totalEvents: 0,
                criticalEvents: 0,
                highSeverityEvents: 0,
                mediumSeverityEvents: 0,
                lowSeverityEvents: 0,
                events: [],
                summary: "Forensic report for \(domain)"
            )
            
            completion(.success(report))
        }
    }
    
    // MARK: - Helper Methods
    
    private func dictionaryToJSON(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}

// MARK: - Data Structures

enum TamperEventType: String {
    case scriptInjection = "script_injection"
    case domManipulation = "dom_manipulation"
    case userAgentAccess = "user_agent_access"
    case headerInjection = "header_injection"
    case certificateMismatch = "certificate_mismatch"
    case cookieTampering = "cookie_tampering"
    case dnsSpoofing = "dns_spoofing"
    case timingAnomaly = "timing_anomaly"
    case fetchIntercept = "fetch_intercept"
    case xhrIntercept = "xhr_intercept"
    case aiChatbotDetected = "ai_chatbot_detected"
}

enum TamperSeverity: String {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

struct ForensicReport {
    let domain: String
    let reportGeneratedAt: Date
    let totalEvents: Int
    let criticalEvents: Int
    let highSeverityEvents: Int
    let mediumSeverityEvents: Int
    let lowSeverityEvents: Int
    let events: [TamperDetection]
    let summary: String
}

// MARK: - AI Chatbot Specific Monitoring

extension TamperDetectionSystem {
    
    /// Enhanced monitoring specifically for AI chatbot sites
    func monitorAIChatbot(domain: String) {
        guard isAIChatbotDomain(domain) else { return }
        
        logTamperEvent(
            type: .aiChatbotDetected,
            domain: domain,
            evidence: [
                "detectedAt": Date().timeIntervalSince1970,
                "enhancedMonitoring": true
            ],
            severity: .low
        )
        
        print("🤖 Enhanced monitoring enabled for AI chatbot: \(domain)")
    }
    
    /// Verify integrity of AI chatbot responses
    func verifyResponseIntegrity(domain: String, responseHash: String, expectedPattern: String?) {
        // This could be used to detect if AI responses are being modified
        // by checking against expected patterns or hashes
        
        if let expected = expectedPattern, !responseHash.contains(expected) {
            logTamperEvent(
                type: .domManipulation,
                domain: domain,
                evidence: [
                    "responseHash": responseHash,
                    "expectedPattern": expected,
                    "possibleModification": true
                ],
                severity: .high
            )
        }
    }
}
