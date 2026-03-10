//
//  NearbyTransfer.swift
//  SchoolTool
//
//  Created by Tim on 10.03.26.
//

import SwiftUI
import Foundation

#if !os(watchOS)
import MultipeerConnectivity

// MARK: - Transfer Payload Models

struct FeedTransferItem: Codable {
    var urlString: String
    var customTitle: String?
}

struct NearbyTransferPayload: Codable {
    var schedule: TimeTableSchedule?
    var feeds: [FeedTransferItem]?
}

// MARK: - NearbyTransferManager

class NearbyTransferManager: NSObject, ObservableObject {
    static let shared = NearbyTransferManager()

    private static let serviceType = "schooltool"

    private let myPeerID: MCPeerID
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!

    @Published var discoveredPeers: [MCPeerID] = []
    @Published var connectedPeers: [MCPeerID] = []
    @Published var isActive = false
    @Published var isSending = false
    @Published var statusMessage: String?

    @Published var receivedPayload: NearbyTransferPayload?
    @Published var receivedFromPeerName: String?
    @Published var incomingInvitationFromName: String?

    private var pendingInvitationHandler: ((Bool, MCSession?) -> Void)?

    override init() {
        #if os(macOS)
        let name = Host.current().localizedName ?? "Mac"
        #else
        let name = UIDevice.current.name
        #endif
        myPeerID = MCPeerID(displayName: name)
        super.init()
        setupSession()
    }

    private func setupSession() {
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: Self.serviceType)
        advertiser.delegate = self
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: Self.serviceType)
        browser.delegate = self
    }

    var myDisplayName: String { myPeerID.displayName }

    func start() {
        guard !isActive else { return }
        discoveredPeers = []
        connectedPeers = []
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        isActive = true
        statusMessage = "Searching for nearby devices…"
    }

    func stop() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
        discoveredPeers = []
        connectedPeers = []
        isActive = false
        statusMessage = nil
    }

    func invite(_ peer: MCPeerID) {
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 30)
        statusMessage = "Inviting \(peer.displayName)…"
    }

    func acceptInvitation() {
        pendingInvitationHandler?(true, session)
        pendingInvitationHandler = nil
        incomingInvitationFromName = nil
    }

    func declineInvitation() {
        pendingInvitationHandler?(false, nil)
        pendingInvitationHandler = nil
        incomingInvitationFromName = nil
    }

    func send(_ payload: NearbyTransferPayload) {
        guard !connectedPeers.isEmpty else {
            statusMessage = "No connected peers"
            return
        }
        isSending = true
        do {
            let data = try JSONEncoder().encode(payload)
            try session.send(data, toPeers: connectedPeers, with: .reliable)
            let names = connectedPeers.map(\.displayName).joined(separator: ", ")
            statusMessage = "Sent to \(names)"
        } catch {
            statusMessage = "Send failed: \(error.localizedDescription)"
        }
        isSending = false
    }

    func clearReceived() {
        receivedPayload = nil
        receivedFromPeerName = nil
    }
}

// MARK: - MCSessionDelegate

extension NearbyTransferManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
                self.discoveredPeers.removeAll { $0 == peerID }
                self.statusMessage = "Connected to \(peerID.displayName)"
            case .connecting:
                self.statusMessage = "Connecting to \(peerID.displayName)…"
            case .notConnected:
                self.connectedPeers.removeAll { $0 == peerID }
                if self.isActive && !self.discoveredPeers.contains(peerID) {
                    self.discoveredPeers.append(peerID)
                }
                self.statusMessage = "\(peerID.displayName) disconnected"
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let payload = try? JSONDecoder().decode(NearbyTransferPayload.self, from: data) else { return }
        DispatchQueue.main.async {
            self.receivedPayload = payload
            self.receivedFromPeerName = peerID.displayName
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream,
                 withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension NearbyTransferManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        DispatchQueue.main.async {
            self.pendingInvitationHandler = invitationHandler
            self.incomingInvitationFromName = peerID.displayName
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension NearbyTransferManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async {
            if !self.discoveredPeers.contains(peerID) && !self.connectedPeers.contains(peerID) {
                self.discoveredPeers.append(peerID)
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll { $0 == peerID }
        }
    }
}

// MARK: - NearbyTransferView

struct NearbyTransferView: View {
    @StateObject private var manager = NearbyTransferManager.shared
    @StateObject private var timeTableManager = TimeTableManager.shared
    @State private var includeSchedule = true
    @State private var includeFeeds = true

    var body: some View {
        Form {
            HStack {
                Spacer()
                ContentUnavailableView(
                    "Nearby Transfer",
                    systemImage: "person.2.wave.2.fill",
                    description: Text("Share your Schedule and Feeds with nearby SchoolTool devices")
                )
                Spacer()
            }
            .listRowBackground(Color.clear)

            Section("This Device") {
                Label(manager.myDisplayName, systemImage: "iphone")
                if let status = manager.statusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Nearby Devices") {
                if !manager.isActive {
                    Text("Tap Start to search for nearby devices")
                        .foregroundStyle(.secondary)
                } else if manager.discoveredPeers.isEmpty && manager.connectedPeers.isEmpty {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Searching…")
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(manager.discoveredPeers, id: \.displayName) { peer in
                    HStack {
                        Label(peer.displayName, systemImage: "iphone.radiowaves.left.and.right")
                        Spacer()
                        Button("Connect") { manager.invite(peer) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }
                ForEach(manager.connectedPeers, id: \.displayName) { peer in
                    Label(peer.displayName, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            if !manager.connectedPeers.isEmpty {
                Section("What to Send") {
                    Toggle("Schedule", isOn: $includeSchedule)
                    #if canImport(FeedKit)
                    Toggle("RSS Feeds", isOn: $includeFeeds)
                    #endif
                }
                Section {
                    Button {
                        sendData()
                    } label: {
                        if manager.isSending {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Sending…")
                            }
                        } else {
                            Label("Send Now", systemImage: "paperplane.fill")
                        }
                    }
                    .disabled(manager.isSending || (!includeSchedule && !includeFeeds))
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Nearby Transfer")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if manager.isActive {
                    Button("Stop", systemImage: "stop.circle") { manager.stop() }
                } else {
                    Button("Start", systemImage: "play.circle") { manager.start() }
                }
            }
        }
        .onAppear { manager.start() }
        .onDisappear { manager.stop() }
        .alert("Incoming Connection", isPresented: Binding(
            get: { manager.incomingInvitationFromName != nil },
            set: { if !$0 { manager.declineInvitation() } }
        )) {
            Button("Accept") { manager.acceptInvitation() }
            Button("Decline", role: .cancel) { manager.declineInvitation() }
        } message: {
            Text("\(manager.incomingInvitationFromName ?? "A nearby device") wants to connect with SchoolTool")
        }
        .sheet(isPresented: Binding(
            get: { manager.receivedPayload != nil },
            set: { if !$0 { manager.clearReceived() } }
        )) {
            ReceivedTransferSheet(manager: manager)
        }
    }

    private func sendData() {
        var payload = NearbyTransferPayload()
        if includeSchedule {
            payload.schedule = timeTableManager.schedule
        }
        #if canImport(FeedKit)
        if includeFeeds {
            payload.feeds = FeedManager.shared.savedFeeds.map {
                FeedTransferItem(urlString: $0.urlString, customTitle: $0.customTitle)
            }
        }
        #endif
        manager.send(payload)
    }
}

// MARK: - ReceivedTransferSheet

struct ReceivedTransferSheet: View {
    @ObservedObject var manager: NearbyTransferManager
    @StateObject private var timeTableManager = TimeTableManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if let payload = manager.receivedPayload {
                    Section("Received from \(manager.receivedFromPeerName ?? "Unknown Device")") {
                        if let schedule = payload.schedule {
                            let dayCount = schedule.days.count
                            let classCount = schedule.days.reduce(0) { $0 + $1.classes.count }
                            Label("\(dayCount) day(s), \(classCount) class(es)", systemImage: "calendar")
                        }
                        #if canImport(FeedKit)
                        if let feeds = payload.feeds {
                            Label("\(feeds.count) RSS feed(s)", systemImage: "dot.radiowaves.up.forward")
                        }
                        #endif
                    }

                    if let schedule = payload.schedule {
                        Section("Schedule") {
                            Button("Import Schedule") {
                                timeTableManager.schedule = schedule
                                manager.clearReceived()
                                dismiss()
                            }
                        }
                    }

                    #if canImport(FeedKit)
                    if let feeds = payload.feeds, !feeds.isEmpty {
                        Section("RSS Feeds") {
                            Button("Merge Feeds") {
                                let existing = FeedManager.shared.savedFeeds
                                let toAdd = feeds
                                    .filter { item in !existing.contains(where: { $0.urlString == item.urlString }) }
                                    .map { SavedFeed(urlString: $0.urlString, customTitle: $0.customTitle) }
                                FeedManager.shared.savedFeeds.append(contentsOf: toAdd)
                                manager.clearReceived()
                                dismiss()
                            }
                            Button("Replace All Feeds", role: .destructive) {
                                FeedManager.shared.savedFeeds = feeds.map {
                                    SavedFeed(urlString: $0.urlString, customTitle: $0.customTitle)
                                }
                                manager.clearReceived()
                                dismiss()
                            }
                        }
                    }
                    #endif
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Received Data")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Dismiss") {
                        manager.clearReceived()
                        dismiss()
                    }
                }
            }
        }
    }
}

#endif // !os(watchOS)
