// ItslearningViews.swift
// SchoolTool

import SwiftUI

#if os(iOS) || os(macOS)
import AuthenticationServices

// MARK: - IdentifiableURL (private helper)

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - ItslearningTabView

struct ItslearningTabView: View {
    @StateObject private var accountManager = ItslearningAccountManager.shared
    @State private var selectedAccount: ItslearningAccount?
    @State private var showAccountPicker = false
    @State private var authenticatedURL: URL?
    @State private var isLoadingURL = false
    @State private var loadError: String?
    @State private var showItslearningSettings = false

    var body: some View {
        NavigationStack {
            if accountManager.accounts.isEmpty {
                noAccountsView
            } else {
                mainContentView
            }
        }
    }

    // MARK: - No Accounts View

    private var noAccountsView: some View {
        ContentUnavailableView {
            Label("No itslearning Account", systemImage: "person.badge.key.fill")
        } description: {
            Text("Sign in to your itslearning account to get started.")
        } actions: {
            Button {
                showItslearningSettings = true
            } label: {
                Label("Open itslearning Settings", systemImage: "gear")
            }
            .borderedProminent()
        }
        .navigationTitle("itslearning")
        .sheet(isPresented: $showItslearningSettings) {
            NavigationStack {
                ItslearningSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showItslearningSettings = false }
                        }
                    }
            }
        }
    }

    // MARK: - Main Content View (has accounts)

    @ViewBuilder
    private var mainContentView: some View {
        Group {
            if let url = authenticatedURL {
                ItslearningSafariView(url: url)
                    .ignoresSafeArea()
            } else if isLoadingURL {
                ProgressView("Loading itslearning…")
            } else if let error = loadError {
                ContentUnavailableView {
                    Label("Failed to Load", systemImage: "exclamationmark.triangle.fill")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") {
                        loadForAccount(selectedAccount ?? accountManager.accounts[0])
                    }
                    .borderedProminent()
                }
            } else {
                ProgressView("Authenticating…")
                    .onAppear { loadInitialAccount() }
            }
        }
        .navigationTitle("itslearning")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if accountManager.accounts.count > 1 {
                        Section("Switch Account") {
                            ForEach(accountManager.accounts) { account in
                                Button {
                                    selectedAccount = account
                                    loadForAccount(account)
                                } label: {
                                    if selectedAccount?.id == account.id {
                                        Label(account.userDisplayName, systemImage: "checkmark")
                                    } else {
                                        Text(account.userDisplayName)
                                    }
                                }
                            }
                        }
                        Divider()
                    }
                    Button {
                        showItslearningSettings = true
                    } label: {
                        Label("itslearning Settings", systemImage: "gear")
                    }
                    if let account = selectedAccount ?? accountManager.accounts.first {
                        Button {
                            loadForAccount(account)
                        } label: {
                            Label("Reload", systemImage: "arrow.clockwise")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showItslearningSettings) {
            NavigationStack {
                ItslearningSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showItslearningSettings = false }
                        }
                    }
            }
        }
    }

    private func loadInitialAccount() {
        let account = accountManager.accounts[0]
        selectedAccount = account
        loadForAccount(account)
    }

    private func loadForAccount(_ account: ItslearningAccount) {
        guard let baseURL = URL(string: account.baseURL) else { return }
        isLoadingURL = true
        authenticatedURL = nil
        loadError = nil
        Task {
            do {
                let url = try await accountManager.getAuthenticatedURL(for: baseURL, account: account)
                await MainActor.run {
                    authenticatedURL = url
                    isLoadingURL = false
                }
            } catch {
                await MainActor.run {
                    loadError = error.localizedDescription
                    isLoadingURL = false
                }
            }
        }
    }
}

// MARK: - ItslearningSafariView

#if os(iOS)
import WebKit
struct ItslearningSafariView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        if webView.url != url {
            webView.load(request)
        }
    }
}
#elseif os(macOS)
import WebKit
struct ItslearningSafariView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        if webView.url != url {
            webView.load(request)
        }
    }
}
#endif

// MARK: - ItslearningSettingsView

struct ItslearningSettingsView: View {
    @StateObject private var accountManager = ItslearningAccountManager.shared
    @State private var showAddAccount = false
    @State private var accountToDelete: ItslearningAccount?

    var body: some View {
        Form {
            HStack {
                Spacer()
                ContentUnavailableView(
                    "itslearning",
                    systemImage: "person.badge.key.fill",
                    description: Text("Manage your itslearning accounts")
                )
                Spacer()
            }
            .listRowBackground(Color.clear)

            Section("Accounts") {
                if accountManager.accounts.isEmpty {
                    Text("No accounts added yet")
                        .foregroundStyle(.secondary)
                }
                ForEach(accountManager.accounts) { account in
                    ItslearningAccountRow(account: account)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        accountManager.removeAccount(accountManager.accounts[index])
                    }
                }
                Button {
                    showAddAccount = true
                } label: {
                    Label("Add Account", systemImage: "plus.circle.fill")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("itslearning")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showAddAccount) {
            ItslearningAddAccountView()
        }
    }
}

// MARK: - ItslearningAccountRow

struct ItslearningAccountRow: View {
    let account: ItslearningAccount

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(account.userDisplayName)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(account.siteTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(account.baseURL)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - ItslearningAddAccountView

struct ItslearningAddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var accountManager = ItslearningAccountManager.shared

    @State private var sites: [ItslearningSite] = []
    @State private var isLoadingSites = true
    @State private var sitesError: String?
    @State private var selectedSite: ItslearningSite?
    @State private var searchText = ""
    @State private var isAuthenticating = false
    @State private var authError: String?

    private var filteredSites: [ItslearningSite] {
        guard !searchText.isEmpty else { return sites }
        let query = searchText.lowercased()
        return sites.filter {
            $0.title.lowercased().contains(query) || $0.shortName.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoadingSites {
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Loading itslearning Sites…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let error = sitesError {
                    ContentUnavailableView {
                        Label("Failed to Load Sites", systemImage: "exclamationmark.triangle.fill")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") { Task { await loadSites() } }
                            .borderedProminent()
                    }
                } else {
                    Form {
                        Picker("Select your itslearning Site", selection: $selectedSite) {
                            Text("None").tag(Optional<ItslearningSite>.none)
                            ForEach(filteredSites) { site in
                                VStack(alignment: .leading) {
                                    Text(site.title).bold()
                                    Text(site.shortName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .tag(Optional(site))
                            }
                        }
                        .pickerStyle(.inline)

                        if let error = authError {
                            Section {
                                Label(error, systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .formStyle(.grouped)
                    #if os(iOS)
                    .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search for a Site")
                    #else
                    .searchable(text: $searchText, prompt: "Search for a Site")
                    #endif
                }
            }
            .navigationTitle("Sign in to itslearning")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isAuthenticating {
                        ProgressView()
                    } else {
                        Button("Sign In") {
                            signIn()
                        }
                        .disabled(selectedSite == nil)
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .task { await loadSites() }
    }

    private func loadSites() async {
        isLoadingSites = true
        sitesError = nil
        do {
            let fetched = try await accountManager.fetchAllSites()
            await MainActor.run {
                sites = fetched
                isLoadingSites = false
            }
        } catch {
            await MainActor.run {
                sitesError = error.localizedDescription
                isLoadingSites = false
            }
        }
    }

    private func signIn() {
        guard let site = selectedSite else { return }
        isAuthenticating = true
        authError = nil
        accountManager.startOAuth(baseURL: site.baseUrl) { result in
            Task { @MainActor in
                switch result {
                case .success(let response):
                    do {
                        let token = try await accountManager.getToken(code: response.code, baseURL: site.baseUrl)
                        // Create a temporary account entry to fetch user info
                        var newAccount = ItslearningAccount(
                            siteTitle: site.title,
                            shortName: site.shortName,
                            baseURL: site.baseUrl,
                            userDisplayName: site.title
                        )
                        accountManager.setToken(token, for: newAccount)
                        // Fetch user info to get display name
                        if let person = try? await accountManager.getUser(for: newAccount) {
                            newAccount.userDisplayName = person.fullName
                        }
                        accountManager.accounts.append(newAccount)
                        dismiss()
                    } catch {
                        authError = error.localizedDescription
                        isAuthenticating = false
                    }
                case .failure(let error):
                    // Ignore cancellation
                    let nsError = error as NSError
                    if nsError.code != ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        authError = error.localizedDescription
                    }
                    isAuthenticating = false
                }
            }
        }
    }
}

// MARK: - ItslearningAuthenticatedLinkView
// Used in Feed articles to open a link with itslearning authentication

struct ItslearningAuthenticatedLinkView: View {
    let url: URL
    let account: ItslearningAccount
    @StateObject private var accountManager = ItslearningAccountManager.shared
    @State private var isLoading = false
    @State private var authenticatedURL: IdentifiableURL?
    @State private var error: String?

    var body: some View {
        Button {
            authenticate()
        } label: {
            if isLoading {
                Label("Authenticating…", systemImage: "key.fill")
            } else {
                Label("Open with itslearning (\(account.userDisplayName))", systemImage: "key.fill")
            }
        }
        .disabled(isLoading)
        .sheet(item: $authenticatedURL) { identifiable in
            NavigationStack {
                ItslearningSafariView(url: identifiable.url)
                    #if os(iOS)
                    .ignoresSafeArea(edges: .bottom)
                    #endif
                    .navigationTitle("itslearning")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { authenticatedURL = nil }
                        }
                    }
            }
        }
        .alert("Authentication Failed", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: {
            if let error { Text(error) }
        }
    }

    private func authenticate() {
        isLoading = true
        Task {
            do {
                let authURL = try await accountManager.getAuthenticatedURL(for: url, account: account)
                await MainActor.run {
                    authenticatedURL = IdentifiableURL(url: authURL)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

#endif // os(iOS) || os(macOS)
