//
//  LibertyBrowserApp.swift
//  LibertyBrowser
//
//  Created by Nathan Visser on 2025-12-12.
//

import SwiftUI
import CryptoKit

@main
struct LibertyBrowserApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            if appState.isAuthenticated {
                ContentView()
                    .onAppear {
                        initializeDatabase()
                    }
            } else {
                AuthenticationView(appState: appState)
            }
        }
    }
    
    private func initializeDatabase() {
        Task {
            do {
                let key = try BiometricAuthManager.shared.getEncryptionKey()
                try EncryptedDatabase.shared.initialize(withKey: key)
                print("✅ Database initialized successfully")
            } catch {
                print("❌ Failed to initialize database: \(error)")
            }
        }
    }
}

// MARK: - App State

class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var authError: String?
}

// MARK: - Authentication View

struct AuthenticationView: View {
    @ObservedObject var appState: AppState
    @State private var isAuthenticating = false
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "lock.shield")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 12) {
                Text("Liberty Browser")
                    .font(.system(size: 32, weight: .bold))
                
                Text("Secure browsing with forensic auditing")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 16) {
                if BiometricAuthManager.shared.isBiometricAvailable() {
                    Button(action: authenticate) {
                        HStack {
                            Image(systemName: biometricIcon())
                                .font(.system(size: 20))
                            Text("Unlock with \(biometricType())")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .frame(width: 280, height: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isAuthenticating)
                } else {
                    Button(action: authenticateWithPasscode) {
                        HStack {
                            Image(systemName: "key.fill")
                                .font(.system(size: 20))
                            Text("Unlock with Passcode")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .frame(width: 280, height: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isAuthenticating)
                }
                
                if isAuthenticating {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if showError, let error = appState.authError {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    Text("End-to-end encrypted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "eye.slash.fill")
                        .foregroundColor(.blue)
                    Text("Zero-knowledge architecture")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .foregroundColor(.orange)
                    Text("Forensic-grade audit logs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: 500, height: 600)
        .onAppear {
            // Auto-authenticate on launch if possible
            if BiometricAuthManager.shared.isBiometricAvailable() {
                // Small delay to let UI settle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    authenticate()
                }
            }
        }
    }
    
    private func authenticate() {
        isAuthenticating = true
        showError = false
        
        Task {
            do {
                try await BiometricAuthManager.shared.authenticate()
                await MainActor.run {
                    appState.isAuthenticated = true
                    isAuthenticating = false
                }
            } catch {
                await MainActor.run {
                    appState.authError = error.localizedDescription
                    showError = true
                    isAuthenticating = false
                }
            }
        }
    }
    
    private func authenticateWithPasscode() {
        isAuthenticating = true
        showError = false
        
        Task {
            do {
                try await BiometricAuthManager.shared.authenticateWithPasscode()
                await MainActor.run {
                    appState.isAuthenticated = true
                    isAuthenticating = false
                }
            } catch {
                await MainActor.run {
                    appState.authError = error.localizedDescription
                    showError = true
                    isAuthenticating = false
                }
            }
        }
    }
    
    private func biometricType() -> String {
        switch BiometricAuthManager.shared.biometricType() {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        default:
            return "Biometrics"
        }
    }
    
    private func biometricIcon() -> String {
        switch BiometricAuthManager.shared.biometricType() {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        default:
            return "lock.fill"
        }
    }
}
