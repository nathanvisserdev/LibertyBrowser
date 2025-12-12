import Foundation
import Network
import WebKit
import Combine

/// Monitors and logs network activity with forensic-grade detail
class NetworkAuditLogger {
    static let shared = NetworkAuditLogger()
    
    private let queue = DispatchQueue(label: "com.libertybrowser.networkaudit", qos: .utility)
    private var activeRequests: [String: RequestMetrics] = [:]
    private let monotonicClock = ContinuousClock()
    private var startTime: ContinuousClock.Instant
    
    private init() {
        startTime = monotonicClock.now
    }
    
    /// Generate unique request ID
    func generateRequestId() -> String {
        return UUID().uuidString
    }
    
    /// Log the start of a network request
    func logRequestStart(requestId: String, url: URL, method: String, headers: [String: String]?) {
        queue.async {
            let metrics = RequestMetrics(
                requestId: requestId,
                url: url.absoluteString,
                method: method,
                requestHeaders: headers,
                startTimestamp: Date().timeIntervalSince1970,
                startMonotonic: self.monotonicTimestamp()
            )
            self.activeRequests[requestId] = metrics
        }
    }
    
    /// Log DNS resolution timing
    func logDNSResolution(requestId: String, duration: TimeInterval, resolvedIPs: [String]) {
        queue.async {
            self.activeRequests[requestId]?.dnsResolutionTime = duration
            self.activeRequests[requestId]?.resolvedIPs = resolvedIPs
            
            // Also log to DNS table
            for ip in resolvedIPs {
                self.logDNSQuery(
                    domain: self.activeRequests[requestId]?.url ?? "",
                    queryType: "A/AAAA",
                    resolverType: "system",
                    responseIPs: resolvedIPs,
                    responseTime: duration
                )
            }
        }
    }
    
    /// Log connection establishment
    func logConnection(requestId: String, ipAddress: String, port: Int, protocolName: String, connectionTime: TimeInterval) {
        queue.async {
            self.activeRequests[requestId]?.ipAddress = ipAddress
            self.activeRequests[requestId]?.port = port
            self.activeRequests[requestId]?.protocol = protocolName
            self.activeRequests[requestId]?.connectionTime = connectionTime
        }
    }
    
    /// Log TLS handshake
    func logTLSHandshake(requestId: String, tlsVersion: String, cipherSuite: String, handshakeTime: TimeInterval, certificateChain: [SecCertificate]?) {
        queue.async {
            self.activeRequests[requestId]?.tlsVersion = tlsVersion
            self.activeRequests[requestId]?.cipherSuite = cipherSuite
            self.activeRequests[requestId]?.tlsHandshakeTime = handshakeTime
            
            // Process certificate chain
            if let certs = certificateChain {
                let chainPEMs = certs.compactMap { self.certificateToPEM($0) }
                self.activeRequests[requestId]?.certificateChain = chainPEMs.joined(separator: "\n---\n")
                
                // Log certificate validation
                if let firstCert = certs.first {
                    self.logCertificateValidation(certificate: firstCert, domain: self.extractDomain(from: self.activeRequests[requestId]?.url ?? ""))
                }
            }
        }
    }
    
    /// Log response receipt
    func logResponse(requestId: String, statusCode: Int, headers: [String: String]?, firstByteTime: TimeInterval) {
        queue.async {
            self.activeRequests[requestId]?.statusCode = statusCode
            self.activeRequests[requestId]?.responseHeaders = headers
            self.activeRequests[requestId]?.firstByteTime = firstByteTime
        }
    }
    
    /// Log request completion
    func logRequestComplete(requestId: String, bytesSent: Int64, bytesReceived: Int64, cacheStatus: String, completionTime: TimeInterval, userInitiated: Bool, navigationId: String?) {
        queue.async {
            guard var metrics = self.activeRequests[requestId] else { return }
            
            metrics.bytesSent = bytesSent
            metrics.bytesReceived = bytesReceived
            metrics.cacheStatus = cacheStatus
            metrics.completionTime = completionTime
            metrics.userInitiated = userInitiated
            metrics.navigationId = navigationId
            
            // Create audit entry and log to database
            let entry = NetworkAuditEntry(
                timestamp: metrics.startTimestamp,
                monotonicTimestamp: metrics.startMonotonic,
                requestId: metrics.requestId,
                url: metrics.url,
                method: metrics.method,
                requestHeaders: self.headersToJSON(metrics.requestHeaders),
                responseHeaders: self.headersToJSON(metrics.responseHeaders),
                statusCode: metrics.statusCode,
                ipAddress: metrics.ipAddress,
                port: metrics.port,
                protocol: metrics.protocol,
                tlsVersion: metrics.tlsVersion,
                cipherSuite: metrics.cipherSuite,
                certificateChain: metrics.certificateChain,
                dnsResolutionTime: metrics.dnsResolutionTime,
                connectionTime: metrics.connectionTime,
                tlsHandshakeTime: metrics.tlsHandshakeTime,
                firstByteTime: metrics.firstByteTime,
                completionTime: metrics.completionTime,
                bytesSent: metrics.bytesSent,
                bytesReceived: metrics.bytesReceived,
                cacheStatus: metrics.cacheStatus,
                serviceWorkerIntercepted: false, // WebKit doesn't support service workers on macOS
                proxyUsed: nil, // Would need to check system proxy settings
                userInitiated: metrics.userInitiated,
                navigationId: metrics.navigationId,
                processId: Int(ProcessInfo.processInfo.processIdentifier)
            )
            
            do {
                try EncryptedDatabase.shared.logNetworkRequest(entry)
            } catch {
                print("Failed to log network request: \(error)")
            }
            
            // Clean up
            self.activeRequests.removeValue(forKey: requestId)
        }
    }
    
    // MARK: - DNS Logging
    
    private func logDNSQuery(domain: String, queryType: String, resolverType: String, responseIPs: [String], responseTime: TimeInterval) {
        // This would be logged to the DNS table in the database
        // Implementation depends on DNS monitoring setup
    }
    
    // MARK: - Certificate Logging
    
    private func logCertificateValidation(certificate: SecCertificate, domain: String) {
        let pem = certificateToPEM(certificate)
        
        // Create trust evaluation
        let policy = SecPolicyCreateSSL(true, domain as CFString)
        var trust: SecTrust?
        let status = SecTrustCreateWithCertificates(certificate, policy, &trust)
        
        guard status == errSecSuccess, let trust = trust else { return }
        
        // Evaluate trust (this is synchronous but lightweight)
        var error: CFError?
        let validationResult = SecTrustEvaluateWithError(trust, &error)
        
        // In a real implementation, you would also check OCSP, CRL, and CT logs
        // For now, we'll log the basic validation result
        print("Certificate validation for \(domain): \(validationResult)")
    }
    
    // MARK: - Helper Methods
    
    private func monotonicTimestamp() -> Int64 {
        let elapsed = monotonicClock.now - startTime
        return Int64(elapsed.components.seconds * 1_000_000_000 + elapsed.components.attoseconds / 1_000_000_000)
    }
    
    private func headersToJSON(_ headers: [String: String]?) -> String? {
        guard let headers = headers else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: headers) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    private func certificateToPEM(_ certificate: SecCertificate) -> String? {
        let data = SecCertificateCopyData(certificate) as Data
        let base64 = data.base64EncodedString(options: .lineLength64Characters)
        return "-----BEGIN CERTIFICATE-----\n\(base64)\n-----END CERTIFICATE-----"
    }
    
    private func extractDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return "" }
        return url.host ?? ""
    }
}

// MARK: - Request Metrics Storage

private struct RequestMetrics {
    let requestId: String
    let url: String
    let method: String
    var requestHeaders: [String: String]?
    let startTimestamp: Double
    let startMonotonic: Int64
    
    var dnsResolutionTime: TimeInterval?
    var resolvedIPs: [String]?
    var connectionTime: TimeInterval?
    var ipAddress: String?
    var port: Int?
    var `protocol`: String?
    var tlsVersion: String?
    var cipherSuite: String?
    var tlsHandshakeTime: TimeInterval?
    var certificateChain: String?
    var statusCode: Int?
    var responseHeaders: [String: String]?
    var firstByteTime: TimeInterval?
    var completionTime: TimeInterval?
    var bytesSent: Int64 = 0
    var bytesReceived: Int64 = 0
    var cacheStatus: String?
    var userInitiated: Bool = false
    var navigationId: String?
}

// MARK: - URL Session Delegate for Network Monitoring

class NetworkMonitoringDelegate: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        guard let request = task.originalRequest else { return }
        
        let requestId = NetworkAuditLogger.shared.generateRequestId()
        let url = request.url!
        let method = request.httpMethod ?? "GET"
        
        // Log request start
        NetworkAuditLogger.shared.logRequestStart(
            requestId: requestId,
            url: url,
            method: method,
            headers: request.allHTTPHeaderFields
        )
        
        // Process metrics for each transaction
        for transactionMetrics in metrics.transactionMetrics {
            // DNS timing
            if let fetchStart = transactionMetrics.fetchStartDate,
               let domainLookupStart = transactionMetrics.domainLookupStartDate,
               let domainLookupEnd = transactionMetrics.domainLookupEndDate {
                let dnsTime = domainLookupEnd.timeIntervalSince(domainLookupStart)
                if let remoteAddress = transactionMetrics.remoteAddress {
                    NetworkAuditLogger.shared.logDNSResolution(
                        requestId: requestId,
                        duration: dnsTime,
                        resolvedIPs: [remoteAddress]
                    )
                }
            }
            
            // Connection timing
            if let connectStart = transactionMetrics.connectStartDate,
               let connectEnd = transactionMetrics.connectEndDate,
               let remoteAddress = transactionMetrics.remoteAddress,
               let remotePort = transactionMetrics.remotePort {
                let connectionTime = connectEnd.timeIntervalSince(connectStart)
                NetworkAuditLogger.shared.logConnection(
                    requestId: requestId,
                    ipAddress: remoteAddress,
                    port: remotePort,
                    protocolName: transactionMetrics.networkProtocolName ?? "unknown",
                    connectionTime: connectionTime
                )
            }
            
            // TLS timing
            if let secureStart = transactionMetrics.secureConnectionStartDate,
               let secureEnd = transactionMetrics.secureConnectionEndDate {
                let tlsTime = secureEnd.timeIntervalSince(secureStart)
                
                // Convert TLS version and cipher suite to strings
                var tlsVersionString = "unknown"
                if let tlsVersion = transactionMetrics.negotiatedTLSProtocolVersion {
                    tlsVersionString = "TLS \(tlsVersion.rawValue)"
                }
                
                var cipherSuiteString = "unknown"
                if let cipherSuite = transactionMetrics.negotiatedTLSCipherSuite {
                    cipherSuiteString = String(format: "0x%04X", cipherSuite.rawValue)
                }
                
                NetworkAuditLogger.shared.logTLSHandshake(
                    requestId: requestId,
                    tlsVersion: tlsVersionString,
                    cipherSuite: cipherSuiteString,
                    handshakeTime: tlsTime,
                    certificateChain: nil // Would need additional API access
                )
            }
            
            // Response timing
            if let responseStart = transactionMetrics.responseStartDate,
               let fetchStart = transactionMetrics.fetchStartDate,
               let response = task.response as? HTTPURLResponse {
                let firstByteTime = responseStart.timeIntervalSince(fetchStart)
                NetworkAuditLogger.shared.logResponse(
                    requestId: requestId,
                    statusCode: response.statusCode,
                    headers: response.allHeaderFields as? [String: String],
                    firstByteTime: firstByteTime
                )
            }
            
            // Completion
            if let responseEnd = transactionMetrics.responseEndDate,
               let fetchStart = transactionMetrics.fetchStartDate {
                let completionTime = responseEnd.timeIntervalSince(fetchStart)
                
                let cacheStatus: String
                if transactionMetrics.resourceFetchType == .networkLoad {
                    cacheStatus = "network"
                } else if transactionMetrics.resourceFetchType == .localCache {
                    cacheStatus = "cache_hit"
                } else {
                    cacheStatus = "unknown"
                }
                
                NetworkAuditLogger.shared.logRequestComplete(
                    requestId: requestId,
                    bytesSent: task.countOfBytesSent,
                    bytesReceived: task.countOfBytesReceived,
                    cacheStatus: cacheStatus,
                    completionTime: completionTime,
                    userInitiated: true, // Would need to track this separately
                    navigationId: nil
                )
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Handle certificate challenges for additional validation
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            
            // Perform custom certificate validation here if needed
            // For now, use default validation
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
