import Foundation
import WebKit

/// Manages cookie storage with encryption and restoration
class CookieManager {
    static let shared = CookieManager()
    
    private init() {}
    
    /// Load cookies from encrypted database and inject into WKWebView
    func loadCookiesForWebView(_ webView: WKWebView, completion: @escaping () -> Void) {
        // Get all unique domains from cookie store
        getAllDomains { domains in
            var loadedCookies = 0
            let totalDomains = domains.count
            
            guard totalDomains > 0 else {
                completion()
                return
            }
            
            for domain in domains {
                self.loadCookiesForDomain(domain, into: webView) {
                    loadedCookies += 1
                    if loadedCookies == totalDomains {
                        completion()
                    }
                }
            }
        }
    }
    
    /// Load cookies for specific domain
    func loadCookiesForDomain(_ domain: String, into webView: WKWebView, completion: @escaping () -> Void) {
        do {
            let cookies = try EncryptedDatabase.shared.getCookies(forDomain: domain)
            
            var setCookieCount = 0
            guard !cookies.isEmpty else {
                completion()
                return
            }
            
            for storedCookie in cookies {
                let cookie = HTTPCookie(properties: [
                    .domain: storedCookie.domain,
                    .path: storedCookie.path ?? "/",
                    .name: storedCookie.name,
                    .value: storedCookie.value,
                    .secure: storedCookie.secure,
                    .expires: storedCookie.expires ?? Date.distantFuture
                ])
                
                if let cookie = cookie {
                    webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie) {
                        setCookieCount += 1
                        if setCookieCount == cookies.count {
                            completion()
                        }
                    }
                } else {
                    setCookieCount += 1
                    if setCookieCount == cookies.count {
                        completion()
                    }
                }
            }
        } catch {
            print("Failed to load cookies for domain \(domain): \(error)")
            completion()
        }
    }
    
    /// Get all domains that have stored cookies
    private func getAllDomains(completion: @escaping ([String]) -> Void) {
        // This would query the database for unique domains
        // For now, return empty array
        completion([])
    }
    
    /// Save all cookies from WKWebView to encrypted database
    func saveCookiesFromWebView(_ webView: WKWebView, completion: @escaping () -> Void) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            for cookie in cookies {
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
            completion()
        }
    }
    
    /// Clear all cookies (both from WebView and database)
    func clearAllCookies(from webView: WKWebView, completion: @escaping () -> Void) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            var deletedCount = 0
            guard !cookies.isEmpty else {
                completion()
                return
            }
            
            for cookie in cookies {
                webView.configuration.websiteDataStore.httpCookieStore.delete(cookie) {
                    deletedCount += 1
                    if deletedCount == cookies.count {
                        // Also clear from database
                        // This would require a database method to clear cookies
                        completion()
                    }
                }
            }
        }
    }
    
    /// Export cookies for forensic analysis
    func exportCookies(completion: @escaping (Result<String, Error>) -> Void) {
        // This would export all cookies to a JSON file with timestamps
        // For forensic purposes
        completion(.failure(NSError(domain: "CookieManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])))
    }
}
