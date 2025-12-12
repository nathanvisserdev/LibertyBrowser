# Liberty Browser - Quick Start Guide

## 🚀 Getting Started in 5 Minutes

### Prerequisites
- Mac with macOS 14.0+ (Sonoma or later)
- Xcode 15.0+
- Face ID/Touch ID or device passcode

### Step 1: Add Files to Xcode Project

All Swift files have been created in the `LibertyBrowser/` folder. Now you need to add them to your Xcode project:

1. Open `LibertyBrowser.xcodeproj` in Xcode
2. In the Project Navigator (left sidebar), right-click on the "LibertyBrowser" folder
3. Select "Add Files to LibertyBrowser..."
4. Navigate to the `LibertyBrowser/` folder
5. Select all the new `.swift` files:
   - `BiometricAuthManager.swift`
   - `CookieManager.swift`
   - `DNSAndTLSMonitor.swift`
   - `EncryptedDatabase.swift`
   - `NetworkAuditLogger.swift`
   - `SecureWebView.swift`
   - `SecurityConfiguration.swift`
   - `TamperDetectionSystem.swift`
   - `iCloudSyncManager.swift`
6. Make sure "Copy items if needed" is **unchecked** (files are already in place)
7. Make sure "Add to targets" has "LibertyBrowser" **checked**
8. Click "Add"

### Step 2: Update Info.plist

Add biometric authentication permission:

1. In Xcode, select the project in the Navigator
2. Select the "LibertyBrowser" target
3. Click the "Info" tab
4. Hover over any row and click the "+" button
5. Add this key-value pair:
   ```
   Key: Privacy - Face ID Usage Description
   Value: Liberty Browser uses Face ID to secure your encrypted browsing data and audit logs.
   ```

### Step 3: Enable Required Capabilities

1. Select the "LibertyBrowser" target
2. Click "Signing & Capabilities" tab
3. Click "+ Capability" button
4. Add **Keychain Sharing**
5. (Optional) Add **iCloud** if you want sync features:
   - Check "CloudKit"
   - The container will auto-generate

### Step 4: Configure Code Signing

1. In "Signing & Capabilities" tab
2. Select your Development Team
3. Xcode will automatically manage signing

### Step 5: Build and Run

1. Select a run destination (e.g., "My Mac")
2. Click the Play button (⌘R) or Product → Run
3. The app will build and launch
4. You'll see the authentication screen
5. Click "Unlock" and authenticate with Face ID/Touch ID
6. Start browsing!

## 🎯 First Time Usage

### Initial Authentication
- On first launch, you'll be prompted to authenticate
- The app will create an encryption key and store it in Keychain
- This key encrypts your database

### Test the Browser
1. Enter a URL like `https://www.google.com`
2. Browse normally
3. Click the shield icon to see security info
4. Click the chart icon to view audit logs

### View Audit Logs
1. Click the chart icon (📊) in the toolbar
2. Switch between log types:
   - **Network**: All HTTP/HTTPS requests with timing
   - **Certificates**: TLS certificate validation records
   - **DNS**: DNS resolution logs
   - **Tamper Detection**: Security events

### Enable iCloud Sync (Optional)
1. Click the gear icon (⚙️) for Settings
2. Toggle "Enable iCloud Sync"
3. Click "Sync Now"
4. Your audit logs will sync to iCloud

## 🔍 Testing Features

### Test Network Auditing
1. Visit `https://example.com`
2. Open Audit Logs
3. View the network request details:
   - URL, method, status code
   - IP address, TLS version
   - Timing information
   - Certificate chain

### Test Tamper Detection
1. Visit `https://chat.openai.com` (or any AI chatbot)
2. The browser will automatically enable enhanced monitoring
3. Open Audit Logs → Tamper Detection
4. You'll see events logged for:
   - AI chatbot detection
   - Script injections
   - Fetch/XHR interceptions

### Test Cookie Management
1. Visit a site that uses cookies (e.g., `https://github.com`)
2. Log in to the site
3. Close the browser
4. Reopen and authenticate
5. Revisit the same site - you should still be logged in
6. Cookies are restored from encrypted storage!

### Test Database Integrity
1. Open Settings (gear icon)
2. Under "Forensic Auditing"
3. Click "Verify Database Integrity"
4. Check the Xcode console for output:
   - `true` = Database is intact
   - `false` = Hash chain is broken (tampering detected)

## 🐛 Troubleshooting

### Build Errors

**Error: Cannot find type 'EncryptedDatabase'**
- Solution: Make sure all .swift files are added to the Xcode target
- File → Add Files to "LibertyBrowser"
- Select all new Swift files
- Check "Add to targets: LibertyBrowser"

**Error: Module 'SQLite3' not found**
- Solution: This should be included by default in macOS
- If not, add `libsqlite3.tbd` to Linked Frameworks

**Error: Missing Face ID permission**
- Solution: Add `NSFaceIDUsageDescription` to Info.plist (see Step 2)

### Runtime Errors

**Error: "Database has not been initialized"**
- Cause: Database initialization failed after authentication
- Solution: Check Xcode console for detailed error
- Ensure app has permission to create files in Application Support directory

**Error: "Biometric authentication failed"**
- Cause: Face ID/Touch ID not available or denied
- Solution: Use the "Unlock with Passcode" option
- Check System Preferences → Security → Allow biometric auth

**App Crashes on Launch**
- Check Xcode console for error messages
- Ensure all capabilities are properly configured
- Try cleaning build folder: Product → Clean Build Folder (⇧⌘K)

### Database Issues

**Want to Reset Database**
```bash
# Delete the database file
rm -rf ~/Library/Application\ Support/LibertyBrowser/liberty_browser.db*
```

**Want to View Database**
```bash
# Database is encrypted, but you can check if it exists
ls -la ~/Library/Application\ Support/LibertyBrowser/
```

## 📱 Advanced Features

### Export Audit Logs
```swift
// Coming soon - export functionality
// Will export to JSON format with cryptographic signatures
```

### Custom Security Policies
Edit `SecurityConfiguration.swift` to customize:
- Minimum TLS version
- Allowed cipher suites
- Certificate pinning
- DNS over HTTPS providers

### Add Certificate Pinning
```swift
// In SecurityConfiguration
SecurityConfiguration.shared.addCertificatePin(
    domain: "example.com",
    publicKeyHash: "sha256_hash_of_public_key"
)
```

## 🎓 Learning Resources

### Understanding the Architecture
- Read `README.md` for full architecture overview
- Check `PERMISSIONS.md` for security requirements
- Review code comments in each Swift file

### Forensic Analysis
- All network requests are logged with precise timing
- Hash chain ensures tamper-evident logging
- Export logs for external forensic tools

### Security Best Practices
1. Always keep app updated
2. Verify database integrity regularly
3. Use strong device passcode
4. Enable iCloud sync for backup
5. Export logs for long-term storage

## 🆘 Getting Help

### Check Logs
```bash
# View system logs
log stream --predicate 'subsystem contains "LibertyBrowser"' --level debug
```

### Common Issues
1. **Can't authenticate**: Restart app and try again
2. **Slow browsing**: Check network connection
3. **Missing logs**: Ensure database initialized correctly
4. **Sync not working**: Check iCloud account status

### Need More Help?
- Check GitHub Issues
- Review the full README.md
- Check Xcode console for detailed errors

## ✅ Success Checklist

- [ ] All Swift files added to Xcode project
- [ ] Info.plist updated with Face ID permission
- [ ] Keychain Sharing capability enabled
- [ ] Code signing configured
- [ ] App builds without errors
- [ ] Authentication works
- [ ] Can browse websites
- [ ] Audit logs are captured
- [ ] Cookies persist across sessions
- [ ] Database integrity verifies successfully

**Congratulations! You now have a fully functional secure browser with forensic auditing!** 🎉

## 🚦 What's Next?

1. **Explore the Features**: Try visiting different websites and viewing the audit logs
2. **Customize Settings**: Adjust security policies to your needs
3. **Test Tamper Detection**: Visit AI chatbot sites and see enhanced monitoring
4. **Export Logs**: (Coming soon) Export for external analysis
5. **Contribute**: Found a bug? Want to add a feature? Contributions welcome!

---

**Happy Secure Browsing!** 🔒🌐
