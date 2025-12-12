# Privacy Permissions Configuration

Add these entries to your Info.plist file for Liberty Browser to function properly:

## Required Permissions

### Face ID / Touch ID Usage
```xml
<key>NSFaceIDUsageDescription</key>
<string>Liberty Browser uses Face ID to secure your encrypted browsing data and audit logs.</string>
```

### Keychain Access
The app automatically uses macOS Keychain - no additional permission needed, but ensure:
- Keychain Sharing capability is enabled in Xcode
- App Sandbox is properly configured

### Network Access
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

### iCloud (Optional - only if enabling sync)
Enable in Xcode Signing & Capabilities:
- iCloud capability
- CloudKit
- Key-value storage

## Hardened Runtime Entitlements

For distribution, ensure these entitlements are set:

```xml
<!-- Allow network connections -->
<key>com.apple.security.network.client</key>
<true/>

<!-- Allow network server (if needed for local testing) -->
<key>com.apple.security.network.server</key>
<true/>

<!-- User Selected File Access -->
<key>com.apple.security.files.user-selected.read-write</key>
<true/>

<!-- Disable library validation for development -->
<key>com.apple.security.cs.disable-library-validation</key>
<true/>
```

## App Sandbox Configuration

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

## CloudKit Container Configuration

If using iCloud sync, configure your CloudKit container:

1. Go to https://icloud.developer.apple.com/
2. Create a container named: `iCloud.com.libertybrowser` (or your bundle ID)
3. Create these record types:
   - NetworkAudit
   - Certificate
   - DNSLog
   - TamperDetection

Each with appropriate fields matching the Swift structs.

## Code Signing

For distribution outside the Mac App Store:

```bash
# Sign the app
codesign --deep --force --verify --verbose --sign "Developer ID Application: Your Name" --options runtime YourApp.app

# Create a DMG
hdiutil create -volname "Liberty Browser" -srcfolder YourApp.app -ov -format UDZO LibertyBrowser.dmg

# Notarize (required for macOS 10.15+)
xcrun notarytool submit LibertyBrowser.dmg --apple-id "your@email.com" --password "app-specific-password" --team-id "TEAMID"
```

## Security Recommendations

1. **Always enable App Sandbox** for distribution
2. **Use Hardened Runtime** for notarization
3. **Never commit** signing certificates or provisioning profiles
4. **Test on clean system** before distribution
5. **Document all permissions** in your privacy policy
