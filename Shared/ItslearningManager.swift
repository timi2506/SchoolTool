import Foundation
import SwiftUI

#if os(iOS)
import AuthenticationServices

// MARK: - ItslearningAccount

struct ItslearningAccount: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var site: AllSitesQuery.itslearningSite
    var token: itslearningToken
    var userInfo: itslearningPerson
}

// MARK: - ItslearningManager

class ItslearningManager: NSObject, ObservableObject {
    static let shared = ItslearningManager()

    private static let clientID = "10ae9d30-1853-48ff-81cb-47b58a325685"

    @Published var accounts: [ItslearningAccount] = []
    @Published var selectedSite: AllSitesQuery.itslearningSite? = nil
    @Published var lastOAuthError: String? = nil

    var presentationContext = PresentationContext()

    private override init() {
        super.init()
        loadAccounts()
    }

    // MARK: - Persistence

    private func loadAccounts() {
        if let data = UserDefaults.standard.data(forKey: "itslearningAccounts"),
           let decoded = try? JSONDecoder().decode([ItslearningAccount].self, from: data) {
            self.accounts = decoded
        }
    }

    func saveAccounts() {
        if let encoded = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(encoded, forKey: "itslearningAccounts")
        }
    }

    func removeAccount(id: UUID) {
        accounts.removeAll { $0.id == id }
        saveAccounts()
    }

    // MARK: - URL Helpers

    func baseURL(for site: AllSitesQuery.itslearningSite) -> URL {
        URL(string: site.baseUrl) ?? URL(string: "https://itslearning.com/")!
    }

    func oauthURL(for site: AllSitesQuery.itslearningSite) -> URL {
        let path = "/oauth2/authorize.aspx"
        let state = UUID().uuidString
        let components: [URLQueryItem] = [
            URLQueryItem(name: "client_id", value: Self.clientID),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "SCOPE"),
            URLQueryItem(name: "redirect_uri", value: "itsl-itslearning://login")
        ]
        var url = baseURL(for: site).appending(path: path.removingPercentEncoding ?? path)
        url.append(queryItems: components)
        return url
    }

    func tokenURL(for site: AllSitesQuery.itslearningSite) -> URL {
        baseURL(for: site).appending(path: "restapi/oauth2/token")
    }

    func personURL(for site: AllSitesQuery.itslearningSite) -> URL {
        baseURL(for: site).appending(path: "restapi/personal/person/v1")
    }

    // MARK: - OAuth Flow

    func startOAuth(for site: AllSitesQuery.itslearningSite) {
        let session = ASWebAuthenticationSession(
            url: oauthURL(for: site),
            callback: .customScheme("itsl-itslearning")
        ) { [weak self] url, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async {
                    self.lastOAuthError = error.localizedDescription
                }
                return
            }
            guard let url, let response = itslearningOAuthResponse(from: url) else { return }
            Task {
                do {
                    try await self.getToken(from: response, site: site)
                } catch {
                    await MainActor.run {
                        self.lastOAuthError = error.localizedDescription
                    }
                }
            }
        }
        session.presentationContextProvider = presentationContext
        session.start()
    }

    func getToken(from response: itslearningOAuthResponse, site: AllSitesQuery.itslearningSite) async throws {
        var request = URLRequest(url: tokenURL(for: site))
        request.httpMethod = "POST"
        let encodedCode = response.code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? response.code
        request.httpBody = "grant_type=authorization_code&client_id=\(Self.clientID)&code=\(encodedCode)".data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let (data, _) = try await URLSession.shared.data(for: request)
        let token = try itslearningToken(from: data)
        let userInfo = try await getUser(token: token, site: site)
        await MainActor.run {
            let account = ItslearningAccount(site: site, token: token, userInfo: userInfo)
            // Replace if same site already exists, otherwise append
            if let idx = self.accounts.firstIndex(where: { $0.site.customerId == site.customerId }) {
                self.accounts[idx] = account
            } else {
                self.accounts.append(account)
            }
            self.saveAccounts()
        }
    }

    func getUser(token: itslearningToken, site: AllSitesQuery.itslearningSite) async throws -> itslearningPerson {
        var request = URLRequest(url: personURL(for: site))
        request.setValue("\(token.tokenType) \(token.accessToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try itslearningPerson(from: data)
    }

    // MARK: - Token Refresh

    func refreshToken(for account: ItslearningAccount) async throws -> ItslearningAccount {
        var request = URLRequest(url: tokenURL(for: account.site))
        request.httpMethod = "POST"
        let encodedRefreshToken = account.token.refreshToken
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? account.token.refreshToken
        request.httpBody = "grant_type=refresh_token&client_id=\(Self.clientID)&refresh_token=\(encodedRefreshToken)".data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let (data, _) = try await URLSession.shared.data(for: request)
        let newToken = try itslearningToken(from: data)
        var updated = account
        updated.token = newToken
        await MainActor.run {
            if let idx = self.accounts.firstIndex(where: { $0.id == account.id }) {
                self.accounts[idx] = updated
                self.saveAccounts()
            }
        }
        return updated
    }

    // MARK: - Authenticated URL

    func getAuthenticatedURL(for url: URL, account: ItslearningAccount) async throws -> URL {
        var currentAccount = account
        if currentAccount.token.expiry.timeIntervalSinceNow <= 0 {
            currentAccount = try await refreshToken(for: currentAccount)
        }
        let token = currentAccount.token
        let ssoBase = baseURL(for: account.site).appending(path: "restapi/personal/sso/url/v1")
        var components = URLComponents(url: ssoBase, resolvingAgainstBaseURL: true)
        components?.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
        guard let endpoint = components?.url else { throw URLError(.badURL) }
        var request = URLRequest(url: endpoint)
        request.setValue("\(token.tokenType) \(token.accessToken)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
        struct SSOResponse: Decodable { let Url: String }
        let decoded = try JSONDecoder().decode(SSOResponse.self, from: data)
        guard let ssoUrl = URL(string: decoded.Url) else { throw URLError(.badURL) }
        return ssoUrl
    }

    // MARK: - URL Matching

    /// Returns the accounts whose base URL is a prefix of the given URL.
    func matchingAccounts(for url: URL) -> [ItslearningAccount] {
        let urlString = url.absoluteString.lowercased()
        return accounts.filter { account in
            let base = account.site.baseUrl.lowercased()
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return urlString.hasPrefix(base)
        }
    }
}
#endif

