import SwiftUI
import WebKit
import Combine

/// Custom WKWebView wrapper with security and monitoring features
struct SecureWebView: NSViewRepresentable {
    @Binding var urlString: String
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var title: String
    
    let coordinator: Coordinator
    
    init(urlString: Binding<String>, isLoading: Binding<Bool>, canGoBack: Binding<Bool>, canGoForward: Binding<Bool>, title: Binding<String>) {
        self._urlString = urlString
        self._isLoading = isLoading
        self._canGoBack = canGoBack
        self._canGoForward = canGoForward
        self._title = title
        self.coordinator = Coordinator(urlString: urlString, isLoading: isLoading, canGoBack: canGoBack, canGoForward: canGoForward, title: title)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = context.coordinator.webView
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Only load if URL changed and is valid
        if let url = URL(string: urlString), url.absoluteString != nsView.url?.absoluteString {
            let request = URLRequest(url: url)
            nsView.load(request)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return coordinator
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let webView: WKWebView
        @Binding var urlString: String
        @Binding var isLoading: Bool
        @Binding var canGoBack: Bool
        @Binding var canGoForward: Bool
        @Binding var title: String
        
        private var navigationStartTime: [String: Date] = [:]
        
        init(urlString: Binding<String>, isLoading: Binding<Bool>, canGoBack: Binding<Bool>, canGoForward: Binding<Bool>, title: Binding<String>) {
            self._urlString = urlString
            self._isLoading = isLoading
            self._canGoBack = canGoBack
            self._canGoForward = canGoForward
            self._title = title
            
            // Configure WKWebView with security settings
            let config = WKWebViewConfiguration()
            
            // Configure default webpage preferences (JavaScript enabled by default, monitored)
            let webpagePreferences = WKWebpagePreferences()
            webpagePreferences.allowsContentJavaScript = true
            config.defaultWebpagePreferences = webpagePreferences
            
            config.preferences.javaScriptCanOpenWindowsAutomatically = false
            
            // Configure content controller for message handling
            let contentController = WKUserContentController()
            
            // Inject tamper detection script
            let tamperDetectionScript = """
            (function() {
                // Detect user agent spoofing attempts
                const originalUserAgent = navigator.userAgent;
                Object.defineProperty(navigator, 'userAgent', {
                    get: function() {
                        window.webkit.messageHandlers.tamperDetection.postMessage({
                            type: 'userAgent_access',
                            timestamp: Date.now()
                        });
                        return originalUserAgent;
                    }
                });
                
                // Monitor for suspicious script injections
                const originalAppendChild = Node.prototype.appendChild;
                Node.prototype.appendChild = function(child) {
                    if (child.tagName === 'SCRIPT') {
                        window.webkit.messageHandlers.tamperDetection.postMessage({
                            type: 'script_injection',
                            src: child.src || 'inline',
                            timestamp: Date.now()
                        });
                    }
                    return originalAppendChild.call(this, child);
                };
                
                // Monitor DOM mutations for manipulation detection
                const observer = new MutationObserver(function(mutations) {
                    mutations.forEach(function(mutation) {
                        if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
                            mutation.addedNodes.forEach(function(node) {
                                if (node.nodeType === 1 && (node.tagName === 'SCRIPT' || node.tagName === 'IFRAME')) {
                                    window.webkit.messageHandlers.tamperDetection.postMessage({
                                        type: 'dom_manipulation',
                                        element: node.tagName,
                                        timestamp: Date.now()
                                    });
                                }
                            });
                        }
                    });
                });
                
                observer.observe(document.documentElement, {
                    childList: true,
                    subtree: true
                });
                
                // Detect known AI chatbot domains and monitor more closely
                const aiDomains = ['openai.com', 'claude.ai', 'gemini.google.com', 'copilot.microsoft.com', 'chat.anthropic.com'];
                const currentDomain = window.location.hostname;
                
                if (aiDomains.some(domain => currentDomain.includes(domain))) {
                    window.webkit.messageHandlers.tamperDetection.postMessage({
                        type: 'ai_chatbot_detected',
                        domain: currentDomain,
                        timestamp: Date.now()
                    });
                    
                    // Enhanced monitoring for AI chatbot sites
                    const originalFetch = window.fetch;
                    window.fetch = function(...args) {
                        window.webkit.messageHandlers.tamperDetection.postMessage({
                            type: 'fetch_intercept',
                            url: args[0],
                            timestamp: Date.now()
                        });
                        return originalFetch.apply(this, args);
                    };
                    
                    // Monitor XMLHttpRequest
                    const originalOpen = XMLHttpRequest.prototype.open;
                    XMLHttpRequest.prototype.open = function(method, url) {
                        window.webkit.messageHandlers.tamperDetection.postMessage({
                            type: 'xhr_intercept',
                            method: method,
                            url: url,
                            timestamp: Date.now()
                        });
                        return originalOpen.apply(this, arguments);
                    };
                }
            })();
            """
            
            let tamperScript = WKUserScript(
                source: tamperDetectionScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
            contentController.addUserScript(tamperScript)
            
            config.userContentController = contentController
            
            // Security settings
            config.websiteDataStore = .nonPersistent() // We'll manage cookies ourselves
            
            // Initialize webView
            self.webView = WKWebView(frame: .zero, configuration: config)
            
            super.init()
            
            // Set delegates
            webView.navigationDelegate = self
            webView.uiDelegate = self
            
            // Add message handler after super.init
            contentController.add(self, name: "tamperDetection")
            
            // Configure custom user agent for privacy
            webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Liberty/1.0"
        }
        
        // MARK: - WKNavigationDelegate
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            
            // Log navigation
            let requestId = NetworkAuditLogger.shared.generateRequestId()
            navigationStartTime[requestId] = Date()
            
            NetworkAuditLogger.shared.logRequestStart(
                requestId: requestId,
                url: url,
                method: navigationAction.request.httpMethod ?? "GET",
                headers: navigationAction.request.allHTTPHeaderFields
            )
            
            // Security checks
            if url.scheme != "https" && url.scheme != "http" && url.scheme != "about" {
                decisionHandler(.cancel)
                return
            }
            
            decisionHandler(.allow)
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.isLoading = true
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.isLoading = false
                self.canGoBack = webView.canGoBack
                self.canGoForward = webView.canGoForward
                self.title = webView.title ?? ""
                self.urlString = webView.url?.absoluteString ?? ""
            }
            
            // Save cookies
            if let url = webView.url {
                saveCookies(for: url)
            }
            
            // Log to browsing history
            if let url = webView.url {
                logToHistory(url: url, title: webView.title ?? "")
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.isLoading = false
            }
            print("Navigation failed: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            // Handle certificate validation
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                if let serverTrust = challenge.protectionSpace.serverTrust {
                    // Perform certificate validation
                    var error: CFError?
                    let isValid = SecTrustEvaluateWithError(serverTrust, &error)
                    
                    if isValid {
                        completionHandler(.useCredential, URLCredential(trust: serverTrust))
                    } else {
                        // Log certificate validation failure
                        print("Certificate validation failed for \(challenge.protectionSpace.host)")
                        completionHandler(.cancelAuthenticationChallenge, nil)
                    }
                } else {
                    completionHandler(.cancelAuthenticationChallenge, nil)
                }
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }
        
        // MARK: - WKUIDelegate
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Handle new window requests
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
        
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            // Handle JavaScript alerts
            let alert = NSAlert()
            alert.messageText = "Alert"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            completionHandler()
        }
        
        // MARK: - WKScriptMessageHandler
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "tamperDetection", let body = message.body as? [String: Any] {
                handleTamperDetection(body)
            }
        }
        
        // MARK: - Helper Methods
        
        private func saveCookies(for url: URL) {
            guard let domain = url.host else { return }
            
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                for cookie in cookies {
                    if cookie.domain.contains(domain) || domain.contains(cookie.domain) {
                        do {
                            try EncryptedDatabase.shared.saveCookie(
                                domain: cookie.domain,
                                name: cookie.name,
                                value: cookie.value,
                                path: cookie.path,
                                expires: cookie.expiresDate,
                                secure: cookie.isSecure,
                                httpOnly: cookie.isHTTPOnly,
                                sameSite: cookie.sameSitePolicy?.rawValue
                            )
                        } catch {
                            print("Failed to save cookie: \(error)")
                        }
                    }
                }
            }
        }
        
        private func logToHistory(url: URL, title: String) {
            // This would log to the browsing_history table
            print("Logging to history: \(url.absoluteString)")
        }
        
        private func handleTamperDetection(_ data: [String: Any]) {
            guard let type = data["type"] as? String else { return }
            guard let timestamp = data["timestamp"] as? Double else { return }
            guard let domain = webView.url?.host else { return }
            
            let detection = TamperDetection(
                timestamp: timestamp / 1000.0, // Convert from JS milliseconds
                domain: domain,
                detectionType: type,
                evidence: String(describing: data),
                severity: determineSeverity(for: type),
                userAgentModified: type == "userAgent_access",
                headerInjectionDetected: false,
                domManipulationDetected: type == "dom_manipulation",
                scriptInjectionDetected: type == "script_injection"
            )
            
            do {
                try EncryptedDatabase.shared.logTamperDetection(detection)
            } catch {
                print("Failed to log tamper detection: \(error)")
            }
        }
        
        private func determineSeverity(for type: String) -> String {
            switch type {
            case "script_injection", "dom_manipulation":
                return "high"
            case "fetch_intercept", "xhr_intercept":
                return "medium"
            default:
                return "low"
            }
        }
    }
}

// MARK: - Browser View Model

class BrowserViewModel: ObservableObject {
    @Published var urlString: String = "https://www.google.com"
    @Published var isLoading: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var title: String = ""
    @Published var showHistory: Bool = false
    @Published var showSettings: Bool = false
    
    func loadURL(_ url: String) {
        var urlToLoad = url
        
        // Add https:// if no scheme provided
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            urlToLoad = "https://\(url)"
        }
        
        urlString = urlToLoad
    }
}
