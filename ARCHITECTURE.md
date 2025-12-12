# Liberty Browser - Architecture Diagram

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Liberty Browser                                 │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    User Interface Layer                          │   │
│  │                                                                   │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐   │   │
│  │  │ ContentView  │  │ Security     │  │ Audit Logs View    │   │   │
│  │  │ (Browser UI) │  │ Info View    │  │ (4 categories)     │   │   │
│  │  └──────────────┘  └──────────────┘  └────────────────────┘   │   │
│  │                                                                   │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐   │   │
│  │  │ Settings     │  │ Auth View    │  │ SecureWebView      │   │   │
│  │  │ View         │  │ (Biometric)  │  │ (WKWebView)        │   │   │
│  │  └──────────────┘  └──────────────┘  └────────────────────┘   │   │
│  └───────────────────────────────────────────────────────────────────┘   │
│                                    │                                      │
│                                    ▼                                      │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                     Security Layer                               │   │
│  │                                                                   │   │
│  │  ┌──────────────────────┐    ┌───────────────────────────┐     │   │
│  │  │ BiometricAuthManager │    │ SecurityConfiguration     │     │   │
│  │  │ • Face ID/Touch ID   │    │ • TLS policies            │     │   │
│  │  │ • Key derivation     │    │ • Certificate pinning     │     │   │
│  │  │ • Keychain storage   │    │ • DNS-over-HTTPS          │     │   │
│  │  └──────────────────────┘    └───────────────────────────┘     │   │
│  │                                                                   │   │
│  │  ┌──────────────────────┐    ┌───────────────────────────┐     │   │
│  │  │ TamperDetectionSystem│    │ DNSAndTLSMonitor          │     │   │
│  │  │ • Script injection   │    │ • DNS resolution          │     │   │
│  │  │ • DOM manipulation   │    │ • TLS handshake           │     │   │
│  │  │ • MITM detection     │    │ • Certificate validation  │     │   │
│  │  └──────────────────────┘    └───────────────────────────┘     │   │
│  └───────────────────────────────────────────────────────────────────┘   │
│                                    │                                      │
│                                    ▼                                      │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    Monitoring Layer                              │   │
│  │                                                                   │   │
│  │  ┌──────────────────────┐    ┌───────────────────────────┐     │   │
│  │  │ NetworkAuditLogger   │    │ CookieManager             │     │   │
│  │  │ • Request tracking   │    │ • Encrypted storage       │     │   │
│  │  │ • Timing metrics     │    │ • Auto restoration        │     │   │
│  │  │ • Metadata capture   │    │ • Domain isolation        │     │   │
│  │  └──────────────────────┘    └───────────────────────────┘     │   │
│  └───────────────────────────────────────────────────────────────────┘   │
│                                    │                                      │
│                                    ▼                                      │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    Storage Layer                                 │   │
│  │                                                                   │   │
│  │  ┌──────────────────────────────────────────────────────────┐  │   │
│  │  │           EncryptedDatabase (SQLite + AES-256-GCM)       │  │   │
│  │  │                                                            │  │   │
│  │  │  ┌──────────────┐ ┌──────────────┐ ┌────────────────┐  │  │   │
│  │  │  │ network_audit│ │certificate_log│ │ dns_log        │  │  │   │
│  │  │  │ (hash chain) │ │ (hash chain)  │ │ (hash chain)   │  │  │   │
│  │  │  └──────────────┘ └──────────────┘ └────────────────┘  │  │   │
│  │  │                                                            │  │   │
│  │  │  ┌──────────────┐ ┌──────────────┐ ┌────────────────┐  │  │   │
│  │  │  │ cookies      │ │ history      │ │ tamper_detect  │  │  │   │
│  │  │  │ (encrypted)  │ │ (hash chain) │ │ (hash chain)   │  │  │   │
│  │  │  └──────────────┘ └──────────────┘ └────────────────┘  │  │   │
│  │  │                                                            │  │   │
│  │  │  ┌──────────────┐ ┌──────────────┐ ┌────────────────┐  │  │   │
│  │  │  │cache_metadata│ │ sync_metadata│ │ integrity_log  │  │  │   │
│  │  │  └──────────────┘ └──────────────┘ └────────────────┘  │  │   │
│  │  └──────────────────────────────────────────────────────────┘  │   │
│  └───────────────────────────────────────────────────────────────────┘   │
│                                    │                                      │
│                                    ▼                                      │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                  Sync Layer (Optional)                           │   │
│  │                                                                   │   │
│  │  ┌───────────────────────────────────────────────────────────┐ │   │
│  │  │              iCloudSyncManager                             │ │   │
│  │  │  • Bidirectional sync                                      │ │   │
│  │  │  • Conflict resolution                                     │ │   │
│  │  │  • Metadata only (privacy-focused)                         │ │   │
│  │  │  • CloudKit backend                                        │ │   │
│  │  └───────────────────────────────────────────────────────────┘ │   │
│  └───────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘

                                    │
                                    ▼
                    ┌───────────────────────────┐
                    │    macOS System Services   │
                    │  • Keychain               │
                    │  • Network Framework      │
                    │  • LocalAuthentication    │
                    │  • WebKit                 │
                    │  • CloudKit               │
                    └───────────────────────────┘
```

## Data Flow - Network Request

```
User enters URL
      │
      ▼
┌─────────────────┐
│  ContentView    │  URL input
└─────────────────┘
      │
      ▼
┌─────────────────┐
│ SecureWebView   │  Load request
└─────────────────┘
      │
      ├──────────────────────┐
      ▼                      ▼
┌──────────────┐    ┌────────────────┐
│ Security     │    │ Network        │
│ Validation   │    │ Audit Logger   │
└──────────────┘    └────────────────┘
      │                      │
      │ ┌────────────────────┤
      │ │                    │
      ▼ ▼                    ▼
┌──────────────┐    ┌────────────────┐
│ WKWebView    │    │ Request        │
│ (WebKit)     │───▶│ Metrics        │
└──────────────┘    └────────────────┘
      │                      │
      ▼                      ▼
┌──────────────┐    ┌────────────────┐
│ DNS          │    │ Connection     │
│ Resolution   │───▶│ Timing         │
└──────────────┘    └────────────────┘
      │                      │
      ▼                      ▼
┌──────────────┐    ┌────────────────┐
│ TLS          │    │ Certificate    │
│ Handshake    │───▶│ Validation     │
└──────────────┘    └────────────────┘
      │                      │
      ▼                      ▼
┌──────────────┐    ┌────────────────┐
│ HTTP         │    │ Response       │
│ Request      │───▶│ Capture        │
└──────────────┘    └────────────────┘
      │                      │
      ▼                      ▼
┌──────────────┐    ┌────────────────┐
│ Response     │    │ Audit Entry    │
│ Received     │───▶│ Complete       │
└──────────────┘    └────────────────┘
      │                      │
      ▼                      ▼
┌──────────────┐    ┌────────────────┐
│ Render Page  │    │ Log to         │
│              │    │ Database       │
└──────────────┘    └────────────────┘
                            │
                            ▼
                    ┌────────────────┐
                    │ Hash Chain     │
                    │ Update         │
                    └────────────────┘
```

## Authentication Flow

```
App Launch
    │
    ▼
┌────────────────────┐
│ AuthenticationView │
└────────────────────┘
    │
    ▼
┌────────────────────┐
│ Biometric Check    │
│ Available?         │
└────────────────────┘
    │
    ├── Yes ────────────┐
    │                   │
    │                   ▼
    │         ┌──────────────────┐
    │         │ Face ID/Touch ID │
    │         │ Prompt           │
    │         └──────────────────┘
    │                   │
    │                   ├── Success ───┐
    │                   │               │
    │                   └── Failure ────┤
    │                                   │
    └── No ─────────────────────────────┤
                                        │
                                        ▼
                              ┌──────────────────┐
                              │ Passcode Prompt  │
                              └──────────────────┘
                                        │
                                        ├── Success ───┐
                                        │               │
                                        └── Failure ────┤
                                                        │
                                                        ▼
                                              ┌──────────────────┐
                                              │ Derive           │
                                              │ Encryption Key   │
                                              └──────────────────┘
                                                        │
                                                        ▼
                                              ┌──────────────────┐
                                              │ Load/Create Key  │
                                              │ from Keychain    │
                                              └──────────────────┘
                                                        │
                                                        ▼
                                              ┌──────────────────┐
                                              │ Initialize       │
                                              │ Database         │
                                              └──────────────────┘
                                                        │
                                                        ▼
                                              ┌──────────────────┐
                                              │ Show ContentView │
                                              │ (Browser)        │
                                              └──────────────────┘
```

## Tamper Detection Flow

```
JavaScript Execution
        │
        ▼
┌───────────────────┐
│ Script Injection  │
│ Detection         │
└───────────────────┘
        │
        ▼
┌───────────────────┐
│ Monitor:          │
│ • eval()          │
│ • Function()      │
│ • createElement   │
│ • appendChild     │
│ • innerHTML       │
└───────────────────┘
        │
        ├── Detected ─────────────┐
        │                         │
        └── Normal ────────────┐  │
                               │  │
                               │  ▼
                               │  ┌──────────────────┐
                               │  │ Log Detection    │
                               │  └──────────────────┘
                               │           │
                               │           ▼
                               │  ┌──────────────────┐
                               │  │ Severity         │
                               │  │ Analysis         │
                               │  └──────────────────┘
                               │           │
                               │           ▼
                               │  ┌──────────────────┐
                               │  │ Evidence         │
                               │  │ Collection       │
                               │  └──────────────────┘
                               │           │
                               │           ▼
                               │  ┌──────────────────┐
                               │  │ Save to          │
                               │  │ tamper_detection │
                               │  └──────────────────┘
                               │           │
                               ▼           ▼
                    ┌──────────────────────────┐
                    │ Continue Browsing        │
                    │ (Security Alert if High) │
                    └──────────────────────────┘
```

## Hash Chain Integrity

```
Record 1
  ├── Data: {request details}
  ├── Hash: SHA256(Data)
  └── Previous Hash: null
         │
         ▼
      Record 2
         ├── Data: {request details}
         ├── Hash: SHA256(Data + Record1.Hash)
         └── Previous Hash: Record1.Hash
                │
                ▼
             Record 3
                ├── Data: {request details}
                ├── Hash: SHA256(Data + Record2.Hash)
                └── Previous Hash: Record2.Hash
                       │
                       ▼
                    Record N
                       ├── Data: {request details}
                       ├── Hash: SHA256(Data + RecordN-1.Hash)
                       └── Previous Hash: RecordN-1.Hash

Verification:
  For each record:
    1. Compute SHA256(Data + PreviousHash)
    2. Compare with stored Hash
    3. If mismatch → Tampering detected!
    4. Use stored Hash as PreviousHash for next record
```

## Component Dependencies

```
LibertyBrowserApp
    │
    ├── AppState
    │
    ├── BiometricAuthManager
    │   └── Keychain (macOS)
    │
    └── ContentView
        │
        ├── BrowserViewModel
        │
        ├── SecureWebView
        │   ├── WKWebView (WebKit)
        │   ├── NetworkAuditLogger
        │   ├── TamperDetectionSystem
        │   └── CookieManager
        │
        ├── SecurityInfoView
        │   └── SecurityConfiguration
        │
        ├── AuditLogsView
        │   └── EncryptedDatabase
        │
        └── SettingsView
            ├── SecurityConfiguration
            ├── iCloudSyncManager
            └── EncryptedDatabase
```

## Security Layers

```
┌────────────────────────────────────────────────────┐
│ Layer 5: User Authentication                       │
│ • Face ID / Touch ID                               │
│ • Device Passcode Fallback                         │
└────────────────────────────────────────────────────┘
                    │
                    ▼
┌────────────────────────────────────────────────────┐
│ Layer 4: Encryption Key Management                 │
│ • SymmetricKey (AES-256)                           │
│ • Keychain Storage (non-sync)                      │
│ • Key Derivation                                   │
└────────────────────────────────────────────────────┘
                    │
                    ▼
┌────────────────────────────────────────────────────┐
│ Layer 3: Data Encryption                           │
│ • AES-256-GCM                                      │
│ • Cookie Encryption                                │
│ • Database Encryption                              │
└────────────────────────────────────────────────────┘
                    │
                    ▼
┌────────────────────────────────────────────────────┐
│ Layer 2: Integrity Verification                    │
│ • SHA-256 Hash Chain                               │
│ • Blockchain-style Linking                         │
│ • Tamper Detection                                 │
└────────────────────────────────────────────────────┘
                    │
                    ▼
┌────────────────────────────────────────────────────┐
│ Layer 1: Network Security                          │
│ • TLS Certificate Validation                       │
│ • Certificate Pinning (optional)                   │
│ • DNS over HTTPS                                   │
└────────────────────────────────────────────────────┘
```

---

This architecture provides:
- ✅ **Defense in Depth**: Multiple security layers
- ✅ **Separation of Concerns**: Clear module boundaries
- ✅ **Tamper Evidence**: Hash chain integrity
- ✅ **Privacy**: Local-first design
- ✅ **Forensics**: Comprehensive audit trail
- ✅ **Extensibility**: Modular components
