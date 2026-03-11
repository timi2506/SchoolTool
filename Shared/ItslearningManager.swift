// ItslearningManager.swift
// SchoolTool

import Foundation
import Combine

#if os(iOS) || os(macOS)
import AuthenticationServices
import Security

// MARK: - Keychain Helper

enum KeychainHelper {
    static func set(_ data: Data, forKey key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        let attributes: [CFString: Any] = [kSecValueData: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    static func get(forKey key: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    static func delete(forKey key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Models

struct ItslearningAccount: Codable, Identifiable, Hashable {
    var id = UUID()
    var siteTitle: String
    var shortName: String
    var baseURL: String
    var userDisplayName: String

    var tokenKey: String { "itslearning-token-\(id.uuidString)" }
}

struct ItslearningToken: Codable, Hashable {
    init(from data: Data) throws {
        let decoded = try JSONDecoder().decode(DecodableToken.self, from: data)
        self.init(from: decoded)
    }

    private init(from decodableToken: DecodableToken) {
        self.accessToken = decodableToken.accessToken
        self.tokenType = decodableToken.tokenType
        self.refreshToken = decodableToken.refreshToken
        self.expiry = Date().addingTimeInterval(decodableToken.expiresIn)
    }

    var accessToken: String
    var tokenType: String
    var refreshToken: String
    var expiry: Date

    var isExpired: Bool { expiry.timeIntervalSinceNow <= 0 }

    private struct DecodableToken: Decodable {
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case tokenType = "token_type"
            case expiresIn = "expires_in"
            case refreshToken = "refresh_token"
        }
        var accessToken: String
        var tokenType: String
        var expiresIn: TimeInterval
        var refreshToken: String
    }
}

struct ItslearningOAuthResponse {
    init?(from url: URL) {
        guard url.scheme == "itsl-itslearning" else { return nil }
        let components = URLComponents(string: url.absoluteString)
        guard let code = components?.queryItems?.first(where: { $0.name == "code" })?.value,
              let state = components?.queryItems?.first(where: { $0.name == "state" })?.value
        else { return nil }
        self.code = code
        self.state = state
    }
    var code: String
    var state: String
}

struct ItslearningSite: Codable, Identifiable, Hashable {
    let customerId: Int
    let title: String
    let shortName: String
    let baseUrl: String
    var id: Int { customerId }

    enum CodingKeys: String, CodingKey {
        case customerId = "CustomerId"
        case title = "Title"
        case shortName = "ShortName"
        case baseUrl = "BaseUrl"
    }
}

struct AllItslearningSitesResponse: Codable {
    var allSites: [ItslearningSite]
    enum CodingKeys: String, CodingKey {
        case allSites = "EntityArray"
    }
}

struct ItslearningPerson: Codable, Hashable {
    var id: Int
    var fullName: String
    var firstName: String
    var lastName: String

    enum CodingKeys: String, CodingKey {
        case id = "PersonId"
        case fullName = "FullName"
        case firstName = "FirstName"
        case lastName = "LastName"
    }
}

// MARK: - ItslearningAccountManager

@MainActor
class ItslearningAccountManager: NSObject, ObservableObject {
    static let shared = ItslearningAccountManager()

    @Published var accounts: [ItslearningAccount] = [] {
        didSet { saveAccounts() }
    }

    private let accountsKey = "itslearningAccounts"

    override init() {
        super.init()
        loadAccounts()
    }

    // MARK: - Persistence

    private func saveAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.shared.set(data, forKey: accountsKey)
        }
    }

    private func loadAccounts() {
        if let data = UserDefaults.shared.data(forKey: accountsKey),
           let decoded = try? JSONDecoder().decode([ItslearningAccount].self, from: data) {
            accounts = decoded
        }
    }

    // MARK: - Token Management

    func token(for account: ItslearningAccount) -> ItslearningToken? {
        guard let data = KeychainHelper.get(forKey: account.tokenKey),
              let token = try? JSONDecoder().decode(ItslearningToken.self, from: data)
        else { return nil }
        return token
    }

    func setToken(_ token: ItslearningToken?, for account: ItslearningAccount) {
        if let token, let data = try? JSONEncoder().encode(token) {
            KeychainHelper.set(data, forKey: account.tokenKey)
        } else {
            KeychainHelper.delete(forKey: account.tokenKey)
        }
    }

    func removeAccount(_ account: ItslearningAccount) {
        KeychainHelper.delete(forKey: account.tokenKey)
        accounts.removeAll { $0.id == account.id }
    }

    // MARK: - OAuth URL Construction

    func oauthURL(for baseURLString: String) -> URL? {
        guard var base = URL(string: baseURLString) else { return nil }
        // Ensure no trailing slash issue
        if !base.absoluteString.hasSuffix("/") {
            base = URL(string: base.absoluteString + "/") ?? base
        }
        // Generate a cryptographically random state value to prevent CSRF
        var stateBytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, stateBytes.count, &stateBytes)
        let state = Data(stateBytes).base64EncodedString()
        var components = URLComponents(
            url: base.appendingPathComponent("oauth2/authorize.aspx"),
            resolvingAgainstBaseURL: true
        )
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: "10ae9d30-1853-48ff-81cb-47b58a325685"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "SCOPE"),
            URLQueryItem(name: "redirect_uri", value: "itsl-itslearning://login")
        ]
        return components?.url
    }

    private var activeAuthSession: ASWebAuthenticationSession?

    // MARK: - OAuth Flow

    func startOAuth(baseURL: String, completion: @escaping @Sendable (Result<ItslearningOAuthResponse, Error>) -> Void) {
        guard let url = oauthURL(for: baseURL) else {
            completion(.failure(URLError(.badURL)))
            return
        }
        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "itsl-itslearning"
        ) { [weak self] callbackURL, error in
            self?.activeAuthSession = nil
            if let error {
                completion(.failure(error))
                return
            }
            guard let callbackURL,
                  let response = ItslearningOAuthResponse(from: callbackURL) else {
                completion(.failure(URLError(.badURL)))
                return
            }
            completion(.success(response))
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        activeAuthSession = session
        session.start()
    }

    // MARK: - Network Helper

    /// Executes a URLRequest, logs the response in DEBUG builds, validates the HTTP status code,
    /// and returns the raw response data. Throws `URLError(.userAuthenticationRequired)` for 401,
    /// `URLError(.badServerResponse)` for any other non-2xx status.
    private func performRequest(_ request: URLRequest, context: String) async throws -> Data {
        #if DEBUG
        let method = request.httpMethod ?? "GET"
        print("[Itslearning] \(context) → \(method) \(request.url?.absoluteString ?? "<nil>")")
        #endif
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        #if DEBUG
        let rawBody = String(data: data, encoding: .utf8) ?? "<non-UTF8 data, \(data.count) bytes>"
        print("[Itslearning] \(context) ← HTTP \(statusCode)\n\(rawBody)")
        #endif
        if statusCode == 401 { throw URLError(.userAuthenticationRequired) }
        guard (200..<300).contains(statusCode) else { throw URLError(.badServerResponse) }
        return data
    }

    func getToken(code: String, baseURL: String) async throws -> ItslearningToken {
        guard let base = URL(string: baseURL) else { throw URLError(.badURL) }
        let tokenURL = base.appendingPathComponent("restapi/oauth2/token")
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.httpBody = "grant_type=authorization_code&client_id=10ae9d30-1853-48ff-81cb-47b58a325685&code=\(code)".data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let data = try await performRequest(request, context: "getToken")
        do {
            return try ItslearningToken(from: data)
        } catch {
            #if DEBUG
            print("[Itslearning] getToken decode error: \(error)")
            #endif
            throw error
        }
    }

    func reAuthToken(for account: ItslearningAccount) async throws -> ItslearningToken {
        guard let current = token(for: account) else { throw URLError(.userAuthenticationRequired) }
        guard let base = URL(string: account.baseURL) else { throw URLError(.badURL) }
        let tokenURL = base.appendingPathComponent("restapi/oauth2/token")
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.httpBody = "grant_type=refresh_token&client_id=10ae9d30-1853-48ff-81cb-47b58a325685&refresh_token=\(current.refreshToken)".data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let data = try await performRequest(request, context: "reAuthToken")
        do {
            return try ItslearningToken(from: data)
        } catch {
            #if DEBUG
            print("[Itslearning] reAuthToken decode error: \(error)")
            #endif
            throw error
        }
    }

    func validToken(for account: ItslearningAccount) async throws -> ItslearningToken {
        if let tok = token(for: account) {
            if !tok.isExpired { return tok }
            let refreshed = try await reAuthToken(for: account)
            setToken(refreshed, for: account)
            return refreshed
        }
        throw URLError(.userAuthenticationRequired)
    }

    func getUser(for account: ItslearningAccount) async throws -> ItslearningPerson {
        let tok = try await validToken(for: account)
        guard let base = URL(string: account.baseURL) else { throw URLError(.badURL) }
        let personURL = base.appendingPathComponent("restapi/personal/person/v1")
        var request = URLRequest(url: personURL)
        request.setValue("\(tok.tokenType) \(tok.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data = try await performRequest(request, context: "getUser")
        do {
            return try JSONDecoder().decode(ItslearningPerson.self, from: data)
        } catch {
            #if DEBUG
            print("[Itslearning] getUser decode error: \(error)")
            #endif
            throw error
        }
    }

    func getAuthenticatedURL(for url: URL, account: ItslearningAccount) async throws -> URL {
        let tok = try await validToken(for: account)
        guard let base = URL(string: account.baseURL) else { throw URLError(.badURL) }
        var components = URLComponents(
            url: base.appendingPathComponent("restapi/personal/sso/url/v1"),
            resolvingAgainstBaseURL: true
        )
        components?.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
        guard let endpoint = components?.url else { throw URLError(.badURL) }
        var request = URLRequest(url: endpoint)
        request.setValue("\(tok.tokenType) \(tok.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data = try await performRequest(request, context: "getAuthenticatedURL")
        struct SSOResponse: Decodable { let Url: String }
        do {
            let decoded = try JSONDecoder().decode(SSOResponse.self, from: data)
            guard let ssoURL = URL(string: decoded.Url) else { throw URLError(.badURL) }
            return ssoURL
        } catch {
            #if DEBUG
            print("[Itslearning] getAuthenticatedURL decode error: \(error)")
            #endif
            throw error
        }
    }

    // MARK: - Site Discovery

    func fetchAllSites() async throws -> [ItslearningSite] {
        let sitesURL = URL(string: "https://itslearning.itslearning.com/restapi/sites/all/v1/")!
        var request = URLRequest(url: sitesURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data = try await performRequest(request, context: "fetchAllSites")
        do {
            let decoded = try JSONDecoder().decode(AllItslearningSitesResponse.self, from: data)
            return decoded.allSites
        } catch {
            #if DEBUG
            print("[Itslearning] fetchAllSites decode error: \(error)")
            #endif
            throw error
        }
    }

    // MARK: - URL Matching

    func matchingAccount(for url: URL) -> ItslearningAccount? {
        guard let urlHost = url.host?.lowercased() else { return nil }
        return accounts.first { account in
            guard let baseHost = URL(string: account.baseURL)?.host?.lowercased() else { return false }
            return urlHost == baseHost || urlHost.hasSuffix(".\(baseHost)") || baseHost.hasSuffix(".\(urlHost)")
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension ItslearningAccountManager: ASWebAuthenticationPresentationContextProviding {
    #if os(iOS)
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }
    #elseif os(macOS)
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.windows.first ?? ASPresentationAnchor()
    }
    #endif
}

#endif // os(iOS) || os(macOS)
