import Foundation
import Security

/// The session token lives in the Keychain (never in a file or in the app's defaults).
private enum Keychain {
    static let service = "com.retromanette.app"
    static let account = "session"

    static func read() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ value: String) {
        delete()
        let attributes: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                         kSecAttrAccount as String: account, kSecValueData as String: Data(value.utf8),
                                         kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func delete() {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
    }
}

/// The account on retromanette.com: the same accounts as the website, so Premium works on a PC, a Mac and a TV. Signing in is
/// optional; the app works fully without an account. The email gets a 6-digit code, and the app stores a session token.
@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var email: String?
    @Published private(set) var isBusy = false
    @Published private(set) var codeSent = false
    /// A localization key for the message to show, or nil.
    @Published private(set) var errorKey: String?

    private var token: String?
    private static let emailKey = "account.email"

    init() {
        token = Keychain.read()
        email = token == nil ? nil : UserDefaults.standard.string(forKey: Self.emailKey)
    }

    var isSignedIn: Bool { token != nil && email != nil }

    func clearMessages() { errorKey = nil }
    func startOver() { codeSent = false; errorKey = nil }

    /// Checks that the stored session is still valid (it may have expired or been removed on another device).
    func restore() async {
        guard let token else { return }
        guard let (status, data) = try? await call("/api/me", method: "GET", body: nil, token: token), status == 200 else { return }
        let user = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["user"]
        if user is NSNull || user == nil { clear() }
    }

    func requestCode(email raw: String) async {
        let address = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard address.contains("@"), address.contains(".") else { errorKey = "account.error.email"; return }
        isBusy = true
        errorKey = nil
        defer { isBusy = false }
        do {
            let (status, _) = try await call("/api/auth/app/request", method: "POST", body: ["email": address], token: nil)
            switch status {
            case 200: codeSent = true
            case 429: errorKey = "account.error.tooMany"
            case 400: errorKey = "account.error.email"
            default: errorKey = "account.error.network"
            }
        } catch {
            errorKey = "account.error.network"
        }
    }

    func verify(email raw: String, code: String) async {
        let address = raw.trimmingCharacters(in: .whitespaces).lowercased()
        isBusy = true
        errorKey = nil
        defer { isBusy = false }
        do {
            let (status, data) = try await call("/api/auth/app/verify", method: "POST", body: ["email": address, "code": code.trimmingCharacters(in: .whitespaces)], token: nil)
            switch status {
            case 200:
                guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let session = object["token"] as? String else {
                    errorKey = "account.error.network"
                    return
                }
                Keychain.write(session)
                UserDefaults.standard.set(address, forKey: Self.emailKey)
                token = session
                email = address
                codeSent = false
            case 429: errorKey = "account.error.tooMany"
            default: errorKey = "account.error.code"
            }
        } catch {
            errorKey = "account.error.network"
        }
    }

    func signOut() async {
        if let token { _ = try? await call("/api/auth/logout", method: "POST", body: nil, token: token) }
        clear()
    }

    /// Removes the account on the server (email, cloud saves, sessions), then signs out here. Games and saves on this device stay.
    func deleteAccount() async -> Bool {
        guard let token else { return false }
        isBusy = true
        defer { isBusy = false }
        guard let (status, _) = try? await call("/api/account/delete", method: "POST", body: nil, token: token), status == 200 else {
            errorKey = "account.error.network"
            return false
        }
        clear()
        return true
    }

    private func clear() {
        Keychain.delete()
        UserDefaults.standard.removeObject(forKey: Self.emailKey)
        token = nil
        email = nil
        codeSent = false
    }

    private func call(_ path: String, method: String, body: [String: String]?, token: String?) async throws -> (Int, Data) {
        var request = URLRequest(url: Site.url(path))
        request.httpMethod = method
        request.timeoutInterval = 20
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        return ((response as? HTTPURLResponse)?.statusCode ?? 0, data)
    }
}
