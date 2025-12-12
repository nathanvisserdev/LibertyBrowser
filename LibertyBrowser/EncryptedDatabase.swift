import Foundation
import CryptoKit
import SQLite3

/// Manages encrypted SQLite database for secure storage of browser data and audit logs
class EncryptedDatabase {
    static let shared = EncryptedDatabase()
    
    private var db: OpaquePointer?
    private var encryptionKey: SymmetricKey?
    private let dbPath: String
    private let fileManager = FileManager.default
    
    // Database file location
    init() {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportPath = paths[0].appendingPathComponent("LibertyBrowser")
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: appSupportPath, withIntermediateDirectories: true)
        
        self.dbPath = appSupportPath.appendingPathComponent("liberty_browser.db").path
    }
    
    /// Initialize database with encryption key derived from biometric auth
    func initialize(withKey key: SymmetricKey) throws {
        self.encryptionKey = key
        
        // Open or create database
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            throw DatabaseError.cannotOpenDatabase
        }
        
        // Enable SQLite encryption extension (requires SQLCipher or custom build)
        // For production, use SQLCipher. This is a placeholder for the structure.
        
        try createTables()
    }
    
    /// Create necessary database tables
    private func createTables() throws {
        // Network audit log table
        let createNetworkAuditTable = """
        CREATE TABLE IF NOT EXISTS network_audit (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp REAL NOT NULL,
            monotonic_timestamp INTEGER NOT NULL,
            request_id TEXT UNIQUE NOT NULL,
            url TEXT NOT NULL,
            method TEXT NOT NULL,
            request_headers TEXT,
            response_headers TEXT,
            status_code INTEGER,
            ip_address TEXT,
            port INTEGER,
            protocol TEXT,
            tls_version TEXT,
            cipher_suite TEXT,
            certificate_chain TEXT,
            dns_resolution_time REAL,
            connection_time REAL,
            tls_handshake_time REAL,
            first_byte_time REAL,
            completion_time REAL,
            bytes_sent INTEGER,
            bytes_received INTEGER,
            cache_status TEXT,
            service_worker_intercepted INTEGER,
            proxy_used TEXT,
            user_initiated INTEGER,
            navigation_id TEXT,
            process_id INTEGER,
            hash TEXT NOT NULL,
            previous_hash TEXT
        );
        """
        
        // Certificate validation log
        let createCertificateTable = """
        CREATE TABLE IF NOT EXISTS certificate_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp REAL NOT NULL,
            domain TEXT NOT NULL,
            certificate_pem TEXT NOT NULL,
            certificate_chain TEXT,
            validation_result TEXT NOT NULL,
            trust_chain TEXT,
            ocsp_response TEXT,
            crl_check TEXT,
            ct_verification TEXT,
            pinning_result TEXT,
            hash TEXT NOT NULL,
            previous_hash TEXT
        );
        """
        
        // DNS query log
        let createDNSTable = """
        CREATE TABLE IF NOT EXISTS dns_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp REAL NOT NULL,
            query_domain TEXT NOT NULL,
            query_type TEXT NOT NULL,
            resolver_type TEXT,
            doh_endpoint TEXT,
            response_ips TEXT,
            response_time REAL,
            ttl INTEGER,
            hash TEXT NOT NULL,
            previous_hash TEXT
        );
        """
        
        // Cookies table (encrypted)
        let createCookiesTable = """
        CREATE TABLE IF NOT EXISTS cookies (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            domain TEXT NOT NULL,
            name TEXT NOT NULL,
            value_encrypted BLOB NOT NULL,
            path TEXT,
            expires REAL,
            secure INTEGER,
            http_only INTEGER,
            same_site TEXT,
            created_at REAL NOT NULL,
            last_accessed REAL NOT NULL,
            UNIQUE(domain, name, path)
        );
        """
        
        // Browsing history
        let createHistoryTable = """
        CREATE TABLE IF NOT EXISTS browsing_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp REAL NOT NULL,
            url TEXT NOT NULL,
            title TEXT,
            visit_duration REAL,
            navigation_type TEXT,
            hash TEXT NOT NULL
        );
        """
        
        // Tamper detection log for AI chatbots
        let createTamperDetectionTable = """
        CREATE TABLE IF NOT EXISTS tamper_detection (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp REAL NOT NULL,
            domain TEXT NOT NULL,
            detection_type TEXT NOT NULL,
            evidence TEXT NOT NULL,
            severity TEXT NOT NULL,
            user_agent_modified INTEGER,
            header_injection_detected INTEGER,
            dom_manipulation_detected INTEGER,
            script_injection_detected INTEGER,
            hash TEXT NOT NULL,
            previous_hash TEXT
        );
        """
        
        // Cache metadata
        let createCacheTable = """
        CREATE TABLE IF NOT EXISTS cache_metadata (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            url TEXT UNIQUE NOT NULL,
            cached_at REAL NOT NULL,
            expires_at REAL,
            etag TEXT,
            last_modified TEXT,
            cache_control TEXT,
            size_bytes INTEGER
        );
        """
        
        // iCloud sync metadata
        let createSyncTable = """
        CREATE TABLE IF NOT EXISTS sync_metadata (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            table_name TEXT NOT NULL,
            record_id INTEGER NOT NULL,
            last_synced REAL,
            sync_status TEXT,
            conflict_data TEXT,
            UNIQUE(table_name, record_id)
        );
        """
        
        // Database integrity log
        let createIntegrityTable = """
        CREATE TABLE IF NOT EXISTS integrity_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp REAL NOT NULL,
            table_name TEXT NOT NULL,
            record_count INTEGER NOT NULL,
            merkle_root TEXT NOT NULL,
            signature TEXT NOT NULL
        );
        """
        
        let tables = [
            createNetworkAuditTable,
            createCertificateTable,
            createDNSTable,
            createCookiesTable,
            createHistoryTable,
            createTamperDetectionTable,
            createCacheTable,
            createSyncTable,
            createIntegrityTable
        ]
        
        for table in tables {
            if sqlite3_exec(db, table, nil, nil, nil) != SQLITE_OK {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                throw DatabaseError.cannotCreateTable(errmsg)
            }
        }
        
        // Create indices for performance
        try createIndices()
    }
    
    private func createIndices() throws {
        let indices = [
            "CREATE INDEX IF NOT EXISTS idx_network_timestamp ON network_audit(timestamp);",
            "CREATE INDEX IF NOT EXISTS idx_network_url ON network_audit(url);",
            "CREATE INDEX IF NOT EXISTS idx_cert_domain ON certificate_log(domain);",
            "CREATE INDEX IF NOT EXISTS idx_dns_domain ON dns_log(query_domain);",
            "CREATE INDEX IF NOT EXISTS idx_cookies_domain ON cookies(domain);",
            "CREATE INDEX IF NOT EXISTS idx_history_timestamp ON browsing_history(timestamp);",
            "CREATE INDEX IF NOT EXISTS idx_tamper_domain ON tamper_detection(domain);"
        ]
        
        for index in indices {
            if sqlite3_exec(db, index, nil, nil, nil) != SQLITE_OK {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                throw DatabaseError.cannotCreateIndex(errmsg)
            }
        }
    }
    
    // MARK: - Network Audit Logging
    
    func logNetworkRequest(_ entry: NetworkAuditEntry) throws {
        guard let db = db else { throw DatabaseError.databaseNotInitialized }
        
        let previousHash = try getLastHash(from: "network_audit")
        let currentHash = try calculateHash(for: entry, previousHash: previousHash)
        
        let insertSQL = """
        INSERT INTO network_audit (
            timestamp, monotonic_timestamp, request_id, url, method, request_headers,
            response_headers, status_code, ip_address, port, protocol, tls_version,
            cipher_suite, certificate_chain, dns_resolution_time, connection_time,
            tls_handshake_time, first_byte_time, completion_time, bytes_sent,
            bytes_received, cache_status, service_worker_intercepted, proxy_used,
            user_initiated, navigation_id, process_id, hash, previous_hash
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_double(statement, 1, entry.timestamp)
            sqlite3_bind_int64(statement, 2, entry.monotonicTimestamp)
            sqlite3_bind_text(statement, 3, entry.requestId, -1, nil)
            sqlite3_bind_text(statement, 4, entry.url, -1, nil)
            sqlite3_bind_text(statement, 5, entry.method, -1, nil)
            sqlite3_bind_text(statement, 6, entry.requestHeaders, -1, nil)
            sqlite3_bind_text(statement, 7, entry.responseHeaders, -1, nil)
            sqlite3_bind_int(statement, 8, Int32(entry.statusCode ?? 0))
            sqlite3_bind_text(statement, 9, entry.ipAddress, -1, nil)
            sqlite3_bind_int(statement, 10, Int32(entry.port ?? 0))
            sqlite3_bind_text(statement, 11, entry.protocol, -1, nil)
            sqlite3_bind_text(statement, 12, entry.tlsVersion, -1, nil)
            sqlite3_bind_text(statement, 13, entry.cipherSuite, -1, nil)
            sqlite3_bind_text(statement, 14, entry.certificateChain, -1, nil)
            sqlite3_bind_double(statement, 15, entry.dnsResolutionTime ?? 0)
            sqlite3_bind_double(statement, 16, entry.connectionTime ?? 0)
            sqlite3_bind_double(statement, 17, entry.tlsHandshakeTime ?? 0)
            sqlite3_bind_double(statement, 18, entry.firstByteTime ?? 0)
            sqlite3_bind_double(statement, 19, entry.completionTime ?? 0)
            sqlite3_bind_int64(statement, 20, entry.bytesSent)
            sqlite3_bind_int64(statement, 21, entry.bytesReceived)
            sqlite3_bind_text(statement, 22, entry.cacheStatus, -1, nil)
            sqlite3_bind_int(statement, 23, entry.serviceWorkerIntercepted ? 1 : 0)
            sqlite3_bind_text(statement, 24, entry.proxyUsed, -1, nil)
            sqlite3_bind_int(statement, 25, entry.userInitiated ? 1 : 0)
            sqlite3_bind_text(statement, 26, entry.navigationId, -1, nil)
            sqlite3_bind_int(statement, 27, Int32(entry.processId))
            sqlite3_bind_text(statement, 28, currentHash, -1, nil)
            sqlite3_bind_text(statement, 29, previousHash, -1, nil)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                throw DatabaseError.insertFailed(errmsg)
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw DatabaseError.prepareFailed(errmsg)
        }
    }
    
    // MARK: - Cookie Management
    
    func saveCookie(domain: String, name: String, value: String, path: String?, expires: Date?, secure: Bool, httpOnly: Bool, sameSite: String?) throws {
        guard let db = db, let encryptionKey = encryptionKey else {
            throw DatabaseError.databaseNotInitialized
        }
        
        // Encrypt cookie value
        let valueData = value.data(using: .utf8)!
        let sealedBox = try AES.GCM.seal(valueData, using: encryptionKey)
        let encryptedValue = sealedBox.combined!
        
        let insertSQL = """
        INSERT OR REPLACE INTO cookies (domain, name, value_encrypted, path, expires, secure, http_only, same_site, created_at, last_accessed)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            let now = Date().timeIntervalSince1970
            sqlite3_bind_text(statement, 1, domain, -1, nil)
            sqlite3_bind_text(statement, 2, name, -1, nil)
            sqlite3_bind_blob(statement, 3, (encryptedValue as NSData).bytes, Int32(encryptedValue.count), nil)
            sqlite3_bind_text(statement, 4, path, -1, nil)
            sqlite3_bind_double(statement, 5, expires?.timeIntervalSince1970 ?? 0)
            sqlite3_bind_int(statement, 6, secure ? 1 : 0)
            sqlite3_bind_int(statement, 7, httpOnly ? 1 : 0)
            sqlite3_bind_text(statement, 8, sameSite, -1, nil)
            sqlite3_bind_double(statement, 9, now)
            sqlite3_bind_double(statement, 10, now)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                throw DatabaseError.insertFailed(errmsg)
            }
        }
    }
    
    func getCookies(forDomain domain: String) throws -> [StoredCookie] {
        guard let db = db, let encryptionKey = encryptionKey else {
            throw DatabaseError.databaseNotInitialized
        }
        
        let querySQL = "SELECT name, value_encrypted, path, expires, secure, http_only, same_site FROM cookies WHERE domain = ?;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        var cookies: [StoredCookie] = []
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, domain, -1, nil)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let name = String(cString: sqlite3_column_text(statement, 0))
                let encryptedData = Data(bytes: sqlite3_column_blob(statement, 1),
                                       count: Int(sqlite3_column_bytes(statement, 1)))
                let path = sqlite3_column_text(statement, 2).map { String(cString: $0) }
                let expires = sqlite3_column_double(statement, 3)
                let secure = sqlite3_column_int(statement, 4) == 1
                let httpOnly = sqlite3_column_int(statement, 5) == 1
                let sameSite = sqlite3_column_text(statement, 6).map { String(cString: $0) }
                
                // Decrypt value
                do {
                    let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
                    let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey)
                    let value = String(data: decryptedData, encoding: .utf8) ?? ""
                    
                    let cookie = StoredCookie(
                        domain: domain,
                        name: name,
                        value: value,
                        path: path,
                        expires: expires > 0 ? Date(timeIntervalSince1970: expires) : nil,
                        secure: secure,
                        httpOnly: httpOnly,
                        sameSite: sameSite
                    )
                    cookies.append(cookie)
                } catch {
                    // Skip corrupted cookies
                    continue
                }
            }
        }
        
        return cookies
    }
    
    // MARK: - Tamper Detection Logging
    
    func logTamperDetection(_ detection: TamperDetection) throws {
        guard let db = db else { throw DatabaseError.databaseNotInitialized }
        
        let previousHash = try getLastHash(from: "tamper_detection")
        let currentHash = try calculateTamperHash(for: detection, previousHash: previousHash)
        
        let insertSQL = """
        INSERT INTO tamper_detection (
            timestamp, domain, detection_type, evidence, severity,
            user_agent_modified, header_injection_detected,
            dom_manipulation_detected, script_injection_detected,
            hash, previous_hash
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_double(statement, 1, detection.timestamp)
            sqlite3_bind_text(statement, 2, detection.domain, -1, nil)
            sqlite3_bind_text(statement, 3, detection.detectionType, -1, nil)
            sqlite3_bind_text(statement, 4, detection.evidence, -1, nil)
            sqlite3_bind_text(statement, 5, detection.severity, -1, nil)
            sqlite3_bind_int(statement, 6, detection.userAgentModified ? 1 : 0)
            sqlite3_bind_int(statement, 7, detection.headerInjectionDetected ? 1 : 0)
            sqlite3_bind_int(statement, 8, detection.domManipulationDetected ? 1 : 0)
            sqlite3_bind_int(statement, 9, detection.scriptInjectionDetected ? 1 : 0)
            sqlite3_bind_text(statement, 10, currentHash, -1, nil)
            sqlite3_bind_text(statement, 11, previousHash, -1, nil)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                throw DatabaseError.insertFailed(errmsg)
            }
        }
    }
    
    // MARK: - Hash Chain Management
    
    private func getLastHash(from table: String) throws -> String? {
        guard let db = db else { throw DatabaseError.databaseNotInitialized }
        
        let querySQL = "SELECT hash FROM \(table) ORDER BY id DESC LIMIT 1;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                if let hashCString = sqlite3_column_text(statement, 0) {
                    return String(cString: hashCString)
                }
            }
        }
        
        return nil
    }
    
    private func calculateHash(for entry: NetworkAuditEntry, previousHash: String?) throws -> String {
        var hasher = SHA256()
        
        hasher.update(data: Data(entry.timestamp.description.utf8))
        hasher.update(data: Data(entry.requestId.utf8))
        hasher.update(data: Data(entry.url.utf8))
        hasher.update(data: Data(entry.method.utf8))
        
        if let prev = previousHash {
            hasher.update(data: Data(prev.utf8))
        }
        
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    private func calculateTamperHash(for detection: TamperDetection, previousHash: String?) throws -> String {
        var hasher = SHA256()
        
        hasher.update(data: Data(detection.timestamp.description.utf8))
        hasher.update(data: Data(detection.domain.utf8))
        hasher.update(data: Data(detection.detectionType.utf8))
        hasher.update(data: Data(detection.evidence.utf8))
        
        if let prev = previousHash {
            hasher.update(data: Data(prev.utf8))
        }
        
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Database Verification
    
    func verifyIntegrity(forTable table: String) throws -> Bool {
        guard let db = db else { throw DatabaseError.databaseNotInitialized }
        
        let querySQL = "SELECT id, hash, previous_hash FROM \(table) ORDER BY id ASC;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        
        var previousHash: String?
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let storedHash = String(cString: sqlite3_column_text(statement, 1))
                let storedPrevious = sqlite3_column_text(statement, 2).map { String(cString: $0) }
                
                if previousHash != storedPrevious {
                    return false // Chain broken
                }
                
                previousHash = storedHash
            }
        }
        
        return true
    }
    
    // MARK: - Cleanup
    
    func close() {
        if let db = db {
            sqlite3_close(db)
            self.db = nil
        }
        encryptionKey = nil
    }
    
    deinit {
        close()
    }
}

// MARK: - Data Structures

struct NetworkAuditEntry {
    let timestamp: Double
    let monotonicTimestamp: Int64
    let requestId: String
    let url: String
    let method: String
    let requestHeaders: String?
    let responseHeaders: String?
    let statusCode: Int?
    let ipAddress: String?
    let port: Int?
    let `protocol`: String?
    let tlsVersion: String?
    let cipherSuite: String?
    let certificateChain: String?
    let dnsResolutionTime: Double?
    let connectionTime: Double?
    let tlsHandshakeTime: Double?
    let firstByteTime: Double?
    let completionTime: Double?
    let bytesSent: Int64
    let bytesReceived: Int64
    let cacheStatus: String?
    let serviceWorkerIntercepted: Bool
    let proxyUsed: String?
    let userInitiated: Bool
    let navigationId: String?
    let processId: Int
}

struct StoredCookie {
    let domain: String
    let name: String
    let value: String
    let path: String?
    let expires: Date?
    let secure: Bool
    let httpOnly: Bool
    let sameSite: String?
}

struct TamperDetection {
    let timestamp: Double
    let domain: String
    let detectionType: String
    let evidence: String
    let severity: String
    let userAgentModified: Bool
    let headerInjectionDetected: Bool
    let domManipulationDetected: Bool
    let scriptInjectionDetected: Bool
}

// MARK: - Errors

enum DatabaseError: Error, LocalizedError {
    case databaseNotInitialized
    case cannotOpenDatabase
    case cannotCreateTable(String)
    case cannotCreateIndex(String)
    case prepareFailed(String)
    case insertFailed(String)
    case queryFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .databaseNotInitialized:
            return "Database has not been initialized"
        case .cannotOpenDatabase:
            return "Cannot open database"
        case .cannotCreateTable(let msg):
            return "Cannot create table: \(msg)"
        case .cannotCreateIndex(let msg):
            return "Cannot create index: \(msg)"
        case .prepareFailed(let msg):
            return "Statement preparation failed: \(msg)"
        case .insertFailed(let msg):
            return "Insert failed: \(msg)"
        case .queryFailed(let msg):
            return "Query failed: \(msg)"
        }
    }
}
