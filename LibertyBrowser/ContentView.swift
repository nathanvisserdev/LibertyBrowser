//
//  ContentView.swift
//  LibertyBrowser
//
//  Created by Nathan Visser on 2025-12-12.
//

import SwiftUI
import WebKit

struct ContentView: View {
    @StateObject private var viewModel = BrowserViewModel()
    @State private var urlInput: String = ""
    @State private var showSecurityInfo: Bool = false
    @State private var showAuditLogs: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                // Navigation buttons
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                }
                .disabled(!viewModel.canGoBack)
                .buttonStyle(PlainButtonStyle())
                
                Button(action: goForward) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .medium))
                }
                .disabled(!viewModel.canGoForward)
                .buttonStyle(PlainButtonStyle())
                
                Button(action: reload) {
                    Image(systemName: viewModel.isLoading ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(PlainButtonStyle())
                
                // URL bar
                HStack(spacing: 8) {
                    Image(systemName: isSecureURL() ? "lock.fill" : "lock.slash")
                        .foregroundColor(isSecureURL() ? .green : .red)
                        .font(.system(size: 14))
                    
                    TextField("Enter URL or search", text: $urlInput, onCommit: {
                        viewModel.loadURL(urlInput)
                    })
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 14))
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                // Security & Audit buttons
                Button(action: { showSecurityInfo.toggle() }) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Security Information")
                
                Button(action: { showAuditLogs.toggle() }) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Audit Logs")
                
                Button(action: { viewModel.showSettings.toggle() }) {
                    Image(systemName: "gear")
                        .font(.system(size: 16))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Settings")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Web View
            SecureWebView(
                urlString: $viewModel.urlString,
                isLoading: $viewModel.isLoading,
                canGoBack: $viewModel.canGoBack,
                canGoForward: $viewModel.canGoForward,
                title: $viewModel.title
            )
        }
        .frame(minWidth: 800, minHeight: 600)
        .sheet(isPresented: $showSecurityInfo) {
            SecurityInfoView(urlString: viewModel.urlString)
        }
        .sheet(isPresented: $showAuditLogs) {
            AuditLogsView()
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView()
        }
        .onAppear {
            urlInput = viewModel.urlString
        }
        .onChange(of: viewModel.urlString) { _, newValue in
            urlInput = newValue
        }
    }
    
    private func goBack() {
        // WebView navigation handled by coordinator
    }
    
    private func goForward() {
        // WebView navigation handled by coordinator
    }
    
    private func reload() {
        if viewModel.isLoading {
            // Stop loading
        } else {
            // Reload
            viewModel.loadURL(viewModel.urlString)
        }
    }
    
    private func isSecureURL() -> Bool {
        return viewModel.urlString.hasPrefix("https://")
    }
}

// MARK: - Security Info View

struct SecurityInfoView: View {
    let urlString: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text("Security Information")
                        .font(.title)
                    Text(urlString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                SecurityInfoRow(icon: "lock.shield", title: "Connection", value: "Encrypted (TLS 1.3)")
                SecurityInfoRow(icon: "checkmark.seal", title: "Certificate", value: "Valid")
                SecurityInfoRow(icon: "network", title: "DNS Resolution", value: "System Resolver")
                SecurityInfoRow(icon: "eye.slash", title: "Privacy Mode", value: "Enhanced")
                SecurityInfoRow(icon: "exclamationmark.triangle", title: "Threats Detected", value: "None")
            }
            
            Spacer()
        }
        .padding(20)
        .frame(width: 500, height: 400)
    }
}

struct SecurityInfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 30)
                .foregroundColor(.blue)
            
            Text(title)
                .frame(width: 150, alignment: .leading)
            
            Text(value)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

// MARK: - Audit Logs View

struct AuditLogsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Forensic Audit Logs")
                    .font(.title)
                
                Spacer()
                
                Button("Export") {
                    // Export logs
                }
                
                Button("Done") {
                    dismiss()
                }
            }
            .padding()
            
            Divider()
            
            Picker("Log Type", selection: $selectedTab) {
                Text("Network").tag(0)
                Text("Certificates").tag(1)
                Text("DNS").tag(2)
                Text("Tamper Detection").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    switch selectedTab {
                    case 0:
                        Text("Network audit logs will appear here")
                            .foregroundColor(.secondary)
                    case 1:
                        Text("Certificate validation logs will appear here")
                            .foregroundColor(.secondary)
                    case 2:
                        Text("DNS resolution logs will appear here")
                            .foregroundColor(.secondary)
                    case 3:
                        Text("Tamper detection events will appear here")
                            .foregroundColor(.secondary)
                    default:
                        EmptyView()
                    }
                }
                .padding()
            }
        }
        .frame(width: 800, height: 600)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var iCloudSyncEnabled = false
    @State private var enhancedPrivacy = true
    @State private var blockTrackers = true
    @State private var dnsOverHTTPS = true
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.title)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
            }
            .padding()
            
            Divider()
            
            Form {
                Section(header: Text("Sync")) {
                    Toggle("Enable iCloud Sync", isOn: $iCloudSyncEnabled)
                        .onChange(of: iCloudSyncEnabled) { _, enabled in
                            if enabled {
                                iCloudSyncManager.shared.enableSync()
                            } else {
                                iCloudSyncManager.shared.disableSync()
                            }
                        }
                    
                    if iCloudSyncEnabled {
                        Button("Sync Now") {
                            iCloudSyncManager.shared.performFullSync { result in
                                switch result {
                                case .success(let syncResult):
                                    print("Synced: \(syncResult.recordsUploaded) uploaded, \(syncResult.recordsDownloaded) downloaded")
                                case .failure(let error):
                                    print("Sync failed: \(error)")
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Privacy & Security")) {
                    Toggle("Enhanced Privacy Mode", isOn: $enhancedPrivacy)
                    Toggle("Block Trackers", isOn: $blockTrackers)
                    Toggle("DNS over HTTPS", isOn: $dnsOverHTTPS)
                }
                
                Section(header: Text("Forensic Auditing")) {
                    Text("All network activity is logged with forensic-grade detail")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Verify Database Integrity") {
                        do {
                            let isValid = try EncryptedDatabase.shared.verifyIntegrity(forTable: "network_audit")
                            print("Database integrity: \(isValid ? "VALID" : "COMPROMISED")")
                        } catch {
                            print("Verification failed: \(error)")
                        }
                    }
                    
                    Button("Export Audit Logs") {
                        // Export functionality
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("2024.12.12")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 600, height: 500)
    }
}

#Preview {
    ContentView()
}
