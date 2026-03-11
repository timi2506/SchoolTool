#if os(iOS)
import SwiftUI
import SafariServices

// MARK: - SafariView

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - ItslearningTabView

struct ItslearningTabView: View {
    @StateObject private var manager = ItslearningManager.shared
    @State private var authenticatedURL: URL? = nil
    @State private var isLoadingURL = false
    @State private var loadError: String? = nil
    @State private var showAccountPicker = false

    var body: some View {
        Group {
            if let url = authenticatedURL {
                // Show SFSafariViewController full-tab — it has its own chrome
                SafariView(url: url)
                    .ignoresSafeArea()
                    .overlay(alignment: .topTrailing) {
                        Button {
                            authenticatedURL = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.secondary)
                                .padding(10)
                        }
                        .accessibilityLabel("Close")
                    }
            } else {
                NavigationStack {
                    Group {
                        if manager.accounts.isEmpty {
                            emptyStateView
                        } else if isLoadingURL {
                            loadingView
                        } else {
                            readyView
                        }
                    }
                    .navigationTitle("itslearning")
                    .toolbar {
                        if !manager.accounts.isEmpty {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Reload", systemImage: "arrow.clockwise") {
                                    openItslearning()
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            if authenticatedURL == nil && !manager.accounts.isEmpty {
                openItslearning()
            }
        }
        .alert("Error", isPresented: Binding(
            get: { loadError != nil },
            set: { if !$0 { loadError = nil } }
        )) {
            Button("Retry") { openItslearning() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let msg = loadError { Text(msg) }
        }
        .confirmationDialog(
            "Select Account",
            isPresented: $showAccountPicker,
            titleVisibility: .visible
        ) {
            ForEach(manager.accounts) { account in
                Button(account.userInfo.fullName) {
                    openAuthenticated(with: account)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose which itslearning account to open")
        }
    }

    // MARK: - Sub-views

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Accounts", systemImage: "person.crop.circle.badge.xmark")
        } description: {
            Text("Sign in to an itslearning account in Settings to get started.")
        } actions: {
            NavigationLink {
                ItslearningSettingsView()
            } label: {
                Label("Go to itslearning Settings", systemImage: "gear")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Opening itslearning…")
                .font(.headline)
            Text("Authenticating your session")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var readyView: some View {
        ContentUnavailableView {
            Label("itslearning", systemImage: "graduationcap.fill")
        } description: {
            Text("Ready to open your itslearning portal.")
        } actions: {
            Button("Open") { openItslearning() }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Actions

    private func openItslearning() {
        if manager.accounts.count == 1 {
            openAuthenticated(with: manager.accounts[0])
        } else if manager.accounts.count > 1 {
            showAccountPicker = true
        }
    }

    private func openAuthenticated(with account: ItslearningAccount) {
        isLoadingURL = true
        loadError = nil
        let baseURL = manager.baseURL(for: account.site)
        Task {
            do {
                let url = try await manager.getAuthenticatedURL(for: baseURL, account: account)
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

// MARK: - ItslearningSettingsView

struct ItslearningSettingsView: View {
    @StateObject private var manager = ItslearningManager.shared
    @State private var showAddAccount = false

    var body: some View {
        Form {
            HStack {
                Spacer()
                ContentUnavailableView(
                    "itslearning",
                    systemImage: "graduationcap.fill",
                    description: Text("Sign into one or more itslearning accounts")
                )
                Spacer()
            }
            Section("Accounts") {
                if manager.accounts.isEmpty {
                    Text("No accounts added yet")
                        .foregroundStyle(.secondary)
                }
                ForEach(manager.accounts) { account in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(account.userInfo.fullName)
                                .bold()
                            Text(account.site.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(account.site.baseUrl)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        manager.removeAccount(id: manager.accounts[index].id)
                    }
                }
            }
            Section {
                Button(action: { showAddAccount = true }) {
                    Label("Add Account", systemImage: "plus.circle.fill")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("itslearning")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddAccount) {
            ItslearningAddAccountView()
        }
        .alert("Sign-in Error", isPresented: Binding(
            get: { manager.lastOAuthError != nil },
            set: { if !$0 { manager.lastOAuthError = nil } }
        )) {
            Button("OK", role: .cancel) { manager.lastOAuthError = nil }
        } message: {
            if let msg = manager.lastOAuthError { Text(msg) }
        }
    }
}

// MARK: - ItslearningAddAccountView

struct ItslearningAddAccountView: View {
    @StateObject private var manager = ItslearningManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var sites: AllSitesQuery? = nil
    @State private var selectedSite: AllSitesQuery.itslearningSite? = nil
    @State private var searchText = ""
    @State private var loadError: String? = nil

    var filteredSites: [AllSitesQuery.itslearningSite] {
        guard let sites else { return [] }
        guard !searchText.isEmpty else { return sites.allSites }
        let q = searchText.lowercased()
        return sites.allSites.filter {
            $0.title.lowercased().contains(q) || $0.shortName.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sites != nil {
                    sitePickerForm
                } else if let error = loadError {
                    errorView(error)
                } else {
                    loadingView
                }
            }
            .navigationTitle("Sign into itslearning")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign in", systemImage: "key.fill") {
                        guard let site = selectedSite else { return }
                        manager.startOAuth(for: site)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedSite == nil)
                }
            }
        }
        .task {
            await fetchSites()
        }
        .interactiveDismissDisabled(sites == nil && loadError == nil)
    }

    // MARK: - Sub-views

    private var sitePickerForm: some View {
        Form {
            Picker("Select your Site", selection: $selectedSite) {
                Text("None").tag(Optional<AllSitesQuery.itslearningSite>.none)
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
        }
        .formStyle(.grouped)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text("Search for a Site")
        )
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large)
            Text("Please wait")
                .bold()
                .font(.title)
            Text("Loading available itslearning Sites")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView(
            "Failed to Load Sites",
            systemImage: "exclamationmark.triangle",
            description: Text(message)
        )
        .overlay(alignment: .bottom) {
            Button("Retry") { Task { await fetchSites() } }
                .buttonStyle(.borderedProminent)
                .padding(.bottom)
        }
    }

    // MARK: - Fetch

    private func fetchSites() async {
        loadError = nil
        do {
            let result = try await AllSitesQuery()
            await MainActor.run { sites = result }
        } catch {
            await MainActor.run { loadError = error.localizedDescription }
        }
    }
}

// MARK: - AuthenticatedURLOpener
// Helper used in Feed or other views to open an itslearning URL with authentication.

struct AuthenticatedURLOpener: View {
    let url: URL
    @StateObject private var manager = ItslearningManager.shared
    @State private var authenticatedURL: URL? = nil
    @State private var isLoading = false
    @State private var error: String? = nil
    @State private var showAccountPicker = false
    @Environment(\.dismiss) private var dismiss

    private var matchingAccounts: [ItslearningAccount] {
        manager.matchingAccounts(for: url)
    }

    var body: some View {
        Group {
            if let authURL = authenticatedURL {
                SafariView(url: authURL)
                    .ignoresSafeArea()
            } else if isLoading {
                VStack(spacing: 16) {
                    ProgressView().controlSize(.large)
                    Text("Authenticating…")
                        .font(.headline)
                }
            } else {
                Text("")
                    .onAppear { resolveAccount() }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            if let msg = error { Text(msg) }
        }
        .confirmationDialog(
            "Select Account",
            isPresented: $showAccountPicker,
            titleVisibility: .visible
        ) {
            ForEach(matchingAccounts) { account in
                Button(account.userInfo.fullName) {
                    open(with: account)
                }
            }
            Button("Open Without Authentication", role: .destructive) {
                authenticatedURL = url
            }
            Button("Cancel", role: .cancel) { dismiss() }
        }
    }

    private func resolveAccount() {
        if matchingAccounts.count == 1 {
            open(with: matchingAccounts[0])
        } else if matchingAccounts.count > 1 {
            showAccountPicker = true
        } else {
            authenticatedURL = url
        }
    }

    private func open(with account: ItslearningAccount) {
        isLoading = true
        Task {
            do {
                let authURL = try await manager.getAuthenticatedURL(for: url, account: account)
                await MainActor.run {
                    authenticatedURL = authURL
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
#endif
