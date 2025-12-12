# Liberty Browser

A secure, privacy-focused web browser for macOS with forensic-grade network auditing capabilities.

## Features

### 🔐 Security
- **Biometric Authentication**: Face ID/Touch ID required to access the browser
- **Encrypted Database**: SQLite database encrypted with AES-256-GCM
- **Zero-Knowledge Architecture**: Encryption keys never leave your device
- **TLS Certificate Validation**: Full certificate chain verification with OCSP/CRL checking
- **Certificate Pinning**: Optional pinning for enhanced security

### 🕵️ Forensic Auditing
- **Network Activity Logging**: Every network request is logged with comprehensive details:
  - DNS resolution timing and resolved IPs
  - TCP/QUIC connection metadata
  - TLS handshake timing, version, and cipher suite
  - Full certificate chains
  - Request/response headers and timing
  - Bytes sent/received
  - Cache vs network attribution
  
- **Tamper Detection**: Advanced monitoring for:
  - Script injection attempts
  - DOM manipulation
  - User agent spoofing
  - Header injection
  - Certificate mismatches (MITM detection)
  - Cookie tampering
  - DNS spoofing
  
- **AI Chatbot Monitoring**: Enhanced surveillance for major AI platforms:
  - OpenAI ChatGPT
  - Anthropic Claude
  - Google Gemini
  - Microsoft Copilot
  - Perplexity AI
  - And more...

- **Cryptographic Integrity**: Hash chain linking all audit records for tamper-evident logging

### 🍪 Cookie Management
- Secure encrypted cookie storage
- Automatic restoration across sessions
- Domain-specific cookie isolation
- HTTPOnly and Secure flag enforcement

### ☁️ iCloud Sync (Optional)
- Sync audit logs across devices
- Encrypted backup to iCloud
- Conflict resolution for multi-device usage
- Privacy-focused: sensitive data never synced

### 🛡️ Privacy Features
- DNS over HTTPS (DoH) support
- No telemetry or analytics
- No data collection
- Local-only processing
- Optional iCloud sync (user-controlled)

## Architecture

### Core Components

1. **EncryptedDatabase** - SQLite database with AES-256-GCM encryption
2. **BiometricAuthManager** - Handles Face ID/Touch ID authentication
3. **NetworkAuditLogger** - Forensic-grade network activity logging
4. **DNSAndTLSMonitor** - Low-level DNS and TLS connection monitoring
5. **TamperDetectionSystem** - Detects and logs tampering attempts
6. **CookieManager** - Secure encrypted cookie storage and restoration
7. **iCloudSyncManager** - Optional cloud synchronization
8. **SecureWebView** - WKWebView wrapper with security enhancements

### Database Schema

The encrypted SQLite database includes these tables:

- `network_audit` - All network requests with timing and metadata
- `certificate_log` - TLS certificate validation records
- `dns_log` - DNS resolution records
- `cookies` - Encrypted cookie storage
- `browsing_history` - URL visit history
- `tamper_detection` - Security event logs
- `cache_metadata` - HTTP cache metadata
- `sync_metadata` - iCloud sync state
- `integrity_log` - Database integrity checksums

Each audit table uses hash chaining for tamper-evident logging.

## Requirements

- macOS 14.0+ (Sonoma or later)
- Xcode 15.0+
- Face ID or Touch ID enabled Mac (or device passcode)
- iCloud account (optional, for sync features)

## Setup

### 1. Clone and Open Project

```bash
git clone <repository-url>
cd LibertyBrowser
open LibertyBrowser.xcodeproj
```

### 2. Configure Signing & Capabilities

In Xcode:
1. Select the LibertyBrowser project
2. Select the LibertyBrowser target
3. Go to "Signing & Capabilities"
4. Add your Apple Developer Team
5. Ensure these capabilities are enabled:
   - **Keychain Sharing** (for secure key storage)
   - **iCloud** (if using sync features)
     - CloudKit
     - Key-value storage

### 3. Configure iCloud (Optional)

If you want iCloud sync:
1. In `iCloudSyncManager.swift`, update the container identifier:
   ```swift
   container = CKContainer(identifier: "iCloud.com.libertybrowser")
   ```
   Change to your bundle identifier.

2. In Xcode capabilities, configure CloudKit with the same identifier.

### 4. SQLCipher (Production Deployment)

For production use, integrate SQLCipher for encrypted SQLite:

```bash
# Using CocoaPods
pod 'SQLCipher'

# Or Swift Package Manager
# Add: https://github.com/sqlcipher/sqlcipher
```

The current implementation uses standard SQLite with application-level encryption. For maximum security, use SQLCipher for database-level encryption.

### 5. Build and Run

```bash
# Build from Xcode (⌘B)
# Or via command line:
xcodebuild -project LibertyBrowser.xcodeproj -scheme LibertyBrowser -configuration Debug
```

## Usage

### First Launch

1. Launch Liberty Browser
2. Authenticate with Face ID/Touch ID (or device passcode)
3. Browser initializes encrypted database
4. You're ready to browse!

### Browsing

- Enter URLs in the address bar
- Navigate with back/forward buttons
- Click the shield icon for security information
- Click the chart icon to view audit logs
- Click the gear icon for settings

### Viewing Audit Logs

1. Click the chart icon in the toolbar
2. Select log type:
   - Network Activity
   - Certificate Validation
   - DNS Queries
   - Tamper Detection
3. Export logs for external analysis

### Enabling iCloud Sync

1. Click the gear icon (Settings)
2. Toggle "Enable iCloud Sync"
3. Click "Sync Now" to perform initial sync
4. Logs will sync automatically going forward

### Verifying Database Integrity

1. Open Settings
2. Under "Forensic Auditing", click "Verify Database Integrity"
3. Check console output for verification result
4. A broken hash chain indicates tampering

## Security Considerations

### Encryption Keys

- Encryption keys are derived from biometric authentication
- Keys are stored in macOS Keychain with highest security
- Keys never sync to iCloud (marked as non-synchronizable)
- Keys are cleared from memory when app locks

### Audit Log Integrity

- Each audit record includes a hash of its contents
- Each hash includes the previous record's hash (blockchain-style)
- Breaking the chain indicates tampering
- Use `verifyIntegrity()` to check chain validity

### Privacy

- All sensitive data is encrypted at rest
- Database file is excluded from backups (.gitignore)
- Cookie values are encrypted before storage
- Full request/response data is NOT synced to iCloud
- Only metadata is synced (if enabled)

### Forensic Validity

For court-grade forensic evidence:

1. **Maintain Chain of Custody**: Document who has access to the device
2. **Regular Integrity Checks**: Verify hash chain regularly
3. **Export with Timestamps**: Export logs with cryptographic signatures
4. **Code Signing**: Ensure app binary is properly signed
5. **Witness Browsing**: Have witnesses present during critical browsing sessions

## Development

### Adding New Features

The modular architecture makes it easy to extend:

- Add new audit log types in `EncryptedDatabase.swift`
- Extend tamper detection in `TamperDetectionSystem.swift`
- Add new security checks in `SecureWebView.swift`
- Implement additional DNS resolvers in `DNSAndTLSMonitor.swift`

### Testing

```bash
# Run tests
xcodebuild test -project LibertyBrowser.xcodeproj -scheme LibertyBrowser

# Or use Xcode (⌘U)
```

## Known Limitations

1. **WebKit Constraints**: Limited to WebKit on macOS (no Chromium/Gecko)
2. **Service Workers**: Not supported by WKWebView on macOS
3. **Full Certificate Access**: Some low-level certificate details require private APIs
4. **DNS Monitoring**: System-level DNS monitoring is limited without root access
5. **SQLCipher**: Not included by default (requires integration)

## Roadmap

- [ ] Full SQLCipher integration
- [ ] PCAP export format
- [ ] Certificate Transparency log verification
- [ ] OCSP/CRL checking implementation
- [ ] DNS over TLS (DoT) support
- [ ] Proxy/VPN detection and logging
- [ ] Extension support with audit logging
- [ ] Multi-window support
- [ ] Bookmark management (encrypted)
- [ ] Advanced search in audit logs
- [ ] Export to forensic analysis tools
- [ ] iOS version

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

[Choose appropriate license]

## Disclaimer

This browser is designed for legitimate forensic investigation and personal security audit purposes. Users are responsible for ensuring their use complies with applicable laws and regulations. The developers are not responsible for misuse of this software.

## Support

For issues, questions, or feature requests, please open an issue on GitHub.

## Acknowledgments

Built with:
- SwiftUI
- WebKit (WKWebView)
- Network Framework
- CryptoKit
- SQLite
- CloudKit

---

**Liberty Browser** - Browse with confidence, audit with certainty.
