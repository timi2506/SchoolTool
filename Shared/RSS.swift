//
//  RSS.swift
//  SchoolTool
//
//  Created by Tim on 10.03.26.
//

import SwiftUI
#if canImport(FeedKit)
import FeedKit

// MARK: - Models

struct SavedFeed: Identifiable, Codable, Equatable {
    var id = UUID()
    var urlString: String
    var customTitle: String?

    var url: URL? { URL(string: urlString) }
    var displayTitle: String { customTitle ?? urlString }
}

struct FeedChannel: Identifiable {
    var id: UUID
    var savedFeed: SavedFeed
    var title: String
    var items: [FeedItem]
    var isLoading: Bool = false
    var errorMessage: String?
    var lastUpdated: Date?

    var displayTitle: String { savedFeed.customTitle ?? title }
}

struct FeedItem: Identifiable {
    var id = UUID()
    var title: String
    var summary: String?
    var link: URL?
    var pubDate: Date?
    var author: String?
}

// MARK: - FeedManager

class FeedManager: ObservableObject {
    static let shared = FeedManager()

    @Published var savedFeeds: [SavedFeed] = [] {
        didSet { save() }
    }
    @Published var channels: [FeedChannel] = []
    @Published var isRefreshing = false

    private let userDefaultsKey = "savedRSSFeeds"

    init() {
        load()
    }

    // MARK: Persistence

    func save() {
        if let data = try? JSONEncoder().encode(savedFeeds) {
            UserDefaults.shared.set(data, forKey: userDefaultsKey)
        }
    }

    func load() {
        if let data = UserDefaults.shared.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([SavedFeed].self, from: data) {
            savedFeeds = decoded
            Task { await performRefresh() }
        }
    }

    // MARK: Feed Management

    func addFeed(urlString: String, customTitle: String? = nil) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !savedFeeds.contains(where: { $0.urlString == trimmed }) else { return }
        let trimmedTitle = customTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title: String? = (trimmedTitle?.isEmpty == false) ? trimmedTitle : nil
        let feed = SavedFeed(urlString: trimmed, customTitle: title)
        savedFeeds.append(feed)
        Task { await fetchFeed(feed) }
    }

    func removeFeed(id: UUID) {
        savedFeeds.removeAll { $0.id == id }
        channels.removeAll { $0.id == id }
    }

    func refreshAll() {
        Task { await performRefresh() }
    }

    /// Async version of refresh — use this in `.refreshable { }` closures.
    func performRefresh() async {
        guard !savedFeeds.isEmpty else { return }
        await MainActor.run { isRefreshing = true }
        await withTaskGroup(of: Void.self) { group in
            for feed in savedFeeds {
                group.addTask { await self.fetchFeed(feed) }
            }
        }
        await MainActor.run { isRefreshing = false }
    }

    // MARK: Fetching

    private func fetchFeed(_ savedFeed: SavedFeed) async {
        guard let url = savedFeed.url else {
            await MainActor.run {
                self.updateChannel(for: savedFeed, items: [], title: savedFeed.displayTitle,
                                    error: "Invalid URL")
            }
            return
        }

        await MainActor.run { self.setLoading(true, for: savedFeed) }

        do {
            let feed = try await Feed(url: url)
            let (items, channelTitle) = Self.extractItems(from: feed, savedFeed: savedFeed)
            await MainActor.run {
                self.updateChannel(for: savedFeed, items: items, title: channelTitle)
            }
        } catch {
            await MainActor.run {
                self.updateChannel(for: savedFeed, items: [], title: savedFeed.displayTitle,
                                    error: error.localizedDescription)
            }
        }
    }

    private static func extractItems(from feed: Feed, savedFeed: SavedFeed) -> ([FeedItem], String) {
        switch feed {
        case .rss(let rssFeed):
            let items: [FeedItem] = rssFeed.channel?.items?.compactMap { item in
                guard let title = item.title else { return nil }
                return FeedItem(
                    title: title,
                    summary: item.description,
                    link: item.link.flatMap { URL(string: $0) },
                    pubDate: item.pubDate,
                    author: item.author
                )
            } ?? []
            return (items, rssFeed.channel?.title ?? savedFeed.displayTitle)

        case .atom(let atomFeed):
            let items: [FeedItem] = atomFeed.entries?.compactMap { entry in
                guard let title = entry.title else { return nil }
                return FeedItem(
                    title: title,
                    summary: entry.summary,
                    link: entry.links?.first?.attributes?.href.flatMap { URL(string: $0) },
                    pubDate: entry.published,
                    author: entry.authors?.first?.name
                )
            } ?? []
            return (items, atomFeed.title ?? savedFeed.displayTitle)

        case .json(let jsonFeed):
            let items: [FeedItem] = jsonFeed.items?.compactMap { item in
                guard let title = item.title else { return nil }
                return FeedItem(
                    title: title,
                    summary: item.contentText ?? item.contentHtml,
                    link: item.url.flatMap { URL(string: $0) },
                    pubDate: item.datePublished,
                    author: item.author?.name
                )
            } ?? []
            return (items, jsonFeed.title ?? savedFeed.displayTitle)
        }
    }

    private func setLoading(_ loading: Bool, for savedFeed: SavedFeed) {
        if let index = channels.firstIndex(where: { $0.id == savedFeed.id }) {
            channels[index].isLoading = loading
        } else {
            let placeholder = FeedChannel(id: savedFeed.id, savedFeed: savedFeed,
                                          title: savedFeed.displayTitle, items: [],
                                          isLoading: true)
            channels.append(placeholder)
        }
    }

    private func updateChannel(for savedFeed: SavedFeed, items: [FeedItem],
                                title: String, error: String? = nil) {
        if let index = channels.firstIndex(where: { $0.id == savedFeed.id }) {
            channels[index].title = title
            channels[index].items = items
            channels[index].isLoading = false
            channels[index].errorMessage = error
            channels[index].lastUpdated = error == nil ? Date() : channels[index].lastUpdated
        } else {
            channels.append(FeedChannel(
                id: savedFeed.id,
                savedFeed: savedFeed,
                title: title,
                items: items,
                isLoading: false,
                errorMessage: error,
                lastUpdated: error == nil ? Date() : nil
            ))
        }
    }
}

// MARK: - FeedsView

struct FeedsView: View {
    @StateObject private var feedManager = FeedManager.shared
    @State private var showAddFeed = false
    @State private var selectedItem: FeedItem?

    private let maxDisplayedItems = 20

    var body: some View {
        NavigationStack {
            Group {
                if feedManager.savedFeeds.isEmpty {
                    emptyStateView
                } else {
                    feedList
                }
            }
            .navigationTitle("Feeds")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if feedManager.isRefreshing {
                        ProgressView()
                    } else {
                        Button {
                            feedManager.refreshAll()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    Button {
                        showAddFeed = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddFeed) {
                AddFeedSheet(feedManager: feedManager)
            }
            .sheet(item: $selectedItem) { item in
                FeedItemDetailView(item: item)
            }
        }
    }

    // MARK: Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "dot.radiowaves.up.forward")
                .font(.system(size: 64))
                .foregroundStyle(.blue.opacity(0.7))
            Text("No Feeds Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Add your favorite RSS, Atom or JSON feeds\nto stay updated.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showAddFeed = true
            } label: {
                Label("Add Feed", systemImage: "plus")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Feed List

    private var feedList: some View {
        List {
            ForEach(feedManager.channels) { channel in
                Section {
                    if channel.isLoading {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Loading…")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else if let error = channel.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    } else if channel.items.isEmpty {
                        Text("No items found")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(channel.items.prefix(maxDisplayedItems)) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                FeedItemRow(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    channelHeader(channel)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await feedManager.performRefresh()
        }
    }

    // MARK: Channel Header

    @ViewBuilder
    private func channelHeader(_ channel: FeedChannel) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundStyle(.blue)
            Text(channel.displayTitle)
                .textCase(nil)
                .fontWeight(.semibold)
            Spacer()
            if let updated = channel.lastUpdated {
                Text(updated, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .textCase(nil)
            }
            Menu {
                if let url = channel.savedFeed.url {
                    Link(destination: url) {
                        Label("Open Feed URL", systemImage: "safari")
                    }
                }
                Button(role: .destructive) {
                    feedManager.removeFeed(id: channel.id)
                } label: {
                    Label("Remove Feed", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - FeedItemRow

struct FeedItemRow: View {
    let item: FeedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
            if let summary = cleanSummary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack(spacing: 10) {
                if let author = item.author {
                    Label(author, systemImage: "person")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if let date = item.pubDate {
                    Label(date.formatted(date: .abbreviated, time: .omitted),
                          systemImage: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var cleanSummary: String? {
        guard let raw = item.summary else { return nil }
        let stripped = raw
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? nil : stripped
    }
}

// MARK: - FeedItemDetailView

struct FeedItemDetailView: View {
    let item: FeedItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(item.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack(spacing: 16) {
                        if let author = item.author {
                            Label(author, systemImage: "person.fill")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let date = item.pubDate {
                            Label(date.formatted(date: .long, time: .omitted),
                                  systemImage: "calendar")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    if let summary = item.summary {
                        let stripped = summary
                            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        Text(stripped)
                            .font(.body)
                    }

                    if let link = item.link {
                        Link(destination: link) {
                            HStack {
                                Spacer()
                                Label("Read Full Article", systemImage: "safari.fill")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue)
                            )
                            .foregroundStyle(.white)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
            }
            .navigationTitle("Article")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if let link = item.link {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: link)
                    }
                }
            }
        }
    }
}

// MARK: - AddFeedSheet

struct AddFeedSheet: View {
    @ObservedObject var feedManager: FeedManager
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @State private var customTitle = ""
    @State private var showInvalidURLAlert = false

    private var isValidURL: Bool {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && URL(string: trimmed) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                HStack {
                    Spacer()
                    ContentUnavailableView(
                        "Add Feed",
                        systemImage: "dot.radiowaves.up.forward",
                        description: Text("Enter the URL of an RSS, Atom or JSON Feed")
                    )
                    Spacer()
                }
                .listRowBackground(Color.clear)

                Section("Feed URL") {
                    TextField("https://example.com/feed.rss", text: $urlText)
                        #if os(iOS)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        #endif
                }

                Section {
                    TextField("My Favorite Blog", text: $customTitle)
                } header: {
                    Text("Custom Title")
                } footer: {
                    Text("Leave blank to use the feed's own title.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Feed")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if isValidURL {
                            feedManager.addFeed(
                                urlString: urlText.trimmingCharacters(in: .whitespacesAndNewlines),
                                customTitle: customTitle
                            )
                            dismiss()
                        } else {
                            showInvalidURLAlert = true
                        }
                    }
                    .disabled(!isValidURL)
                }
            }
            .alert("Invalid URL", isPresented: $showInvalidURLAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please enter a valid feed URL starting with https:// or http://")
            }
        }
    }
}
#endif // canImport(FeedKit)
