//
//  NearbyTransfer.swift
//  SchoolTool
//
//  Created by Tim on 10.03.26.
//

import SwiftUI
import Network

#if os(tvOS) || os(iOS)
import DeviceDiscoveryUI
#endif

#if !os(watchOS)

// MARK: - Transfer Payload Models

struct FeedTransferItem: Codable {
    var urlString: String
    var customTitle: String?
}

struct NearbyTransferPayload: Codable {
    var schedule: TimeTableSchedule?
    var feeds: [FeedTransferItem]?
}

/// Wraps payload together with the sender's human-readable device name.
private struct TransferEnvelope: Codable {
    var senderName: String
    var payload: NearbyTransferPayload
}

// MARK: - NearbyTransferManager

/// Manages Bonjour advertisement (NWListener), peer discovery (NWBrowser)
/// and data exchange (NWConnection) on the local network.
/// tvOS uses the applicationService transport (for DevicePicker);
/// iOS and macOS use _schooltool._tcp Bonjour over TCP.
class NearbyTransferManager: ObservableObject {
    static let shared = NearbyTransferManager()

    /// Application-service name shared by all SchoolTool instances.
    static let applicationServiceName = "schooltool"

    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connections: [NWConnection] = []

    /// Peers discovered by NWBrowser (used by the custom UI on iOS / macOS).
    @Published var discoveredPeers: [(name: String, endpoint: NWEndpoint)] = []
    /// Display names of currently connected peers.
    @Published var connectedPeerNames: [String] = []
    @Published var isActive = false
    @Published var isSending = false
    @Published var statusMessage: String?

    @Published var receivedPayload: NearbyTransferPayload?
    @Published var receivedFromPeerName: String?

    private init() {}

    var deviceName: String {
        #if os(macOS)
        Host.current().localizedName ?? "Mac"
        #else
        UIDevice.current.name
        #endif
    }

    // MARK: - Lifecycle

    func start() {
        guard !isActive else { return }
        isActive = true
        startListener()
        startBrowser()
        statusMessage = "Advertising as \(deviceName)…"
    }

    func stop() {
        listener?.cancel()
        listener = nil
        browser?.cancel()
        browser = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
        discoveredPeers.removeAll()
        connectedPeerNames.removeAll()
        isActive = false
        statusMessage = nil
    }

    // MARK: - Platform-specific network parameters

    /// NWParameters for listener, browser, and connections.
    /// tvOS uses applicationService (required by DevicePicker).
    /// iOS and macOS use plain TCP advertised via Bonjour (_schooltool._tcp).
    private static var transferParameters: NWParameters {
        #if os(tvOS)
        return .applicationService
        #else
        return .tcp
        #endif
    }

    // MARK: - NWListener (advertises this device, accepts incoming connections)

    private func startListener() {
        #if os(tvOS)
        let service = NWListener.Service(applicationService: Self.applicationServiceName)
        #else
        let service = NWListener.Service(name: deviceName, type: "_schooltool._tcp")
        #endif
        guard let l = try? NWListener(service: service, using: Self.transferParameters) else { return }

        l.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                if case .failed(let error) = state {
                    self?.statusMessage = "Network error: \(error.localizedDescription)"
                }
            }
        }

        l.newConnectionHandler = { [weak self] connection in
            DispatchQueue.main.async {
                self?.acceptIncoming(connection)
            }
        }

        l.start(queue: .main)
        listener = l
    }

    // MARK: - NWBrowser (discovers peers for the custom UI on iOS / macOS)

    private func startBrowser() {
        #if os(tvOS)
        let descriptor = NWBrowser.Descriptor.applicationService(name: Self.applicationServiceName)
        #else
        let descriptor = NWBrowser.Descriptor.bonjourWithTXTRecord(
            type: "_schooltool._tcp",
            domain: "local."
        )
        #endif
        let b = NWBrowser(for: descriptor, using: Self.transferParameters)

        b.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            let myName = self.deviceName
            let peers: [(name: String, endpoint: NWEndpoint)] = results.compactMap { result in
                guard case .service(let name, _, _, _) = result.endpoint,
                      name != myName else { return nil }
                return (name: name, endpoint: result.endpoint)
            }
            DispatchQueue.main.async {
                self.discoveredPeers = peers
            }
        }

        b.start(queue: .main)
        browser = b
    }

    // MARK: - Outgoing connection (initiated by user selecting a peer)

    func connect(to endpoint: NWEndpoint) {
        let peerName: String
        if case .service(let name, _, _, _) = endpoint { peerName = name } else { peerName = "Device" }

        let conn = NWConnection(to: endpoint, using: Self.transferParameters)
        setupConnection(conn, peerName: peerName, isOutgoing: true)
        conn.start(queue: .main)
    }

    // MARK: - Incoming connection (accepted by listener)

    private func acceptIncoming(_ conn: NWConnection) {
        setupConnection(conn, peerName: "Remote Device", isOutgoing: false)
        conn.start(queue: .main)
    }

    // MARK: - Shared connection setup

    private func setupConnection(_ conn: NWConnection, peerName: String, isOutgoing: Bool) {
        connections.append(conn)
        if isOutgoing { statusMessage = "Connecting to \(peerName)…" }

        conn.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    if self?.connectedPeerNames.contains(peerName) == false {
                        self?.connectedPeerNames.append(peerName)
                    }
                    if isOutgoing { self?.statusMessage = "Connected to \(peerName)" }
                    self?.receiveNextFrame(on: conn, peerName: peerName)
                case .failed(let error):
                    self?.connectedPeerNames.removeAll { $0 == peerName }
                    self?.connections.removeAll { $0 === conn }
                    if isOutgoing {
                        self?.statusMessage = "Connection failed: \(error.localizedDescription)"
                    }
                case .cancelled:
                    self?.connectedPeerNames.removeAll { $0 == peerName }
                    self?.connections.removeAll { $0 === conn }
                @unknown default:
                    break
                }
            }
        }
    }

    // MARK: - Send (length-prefixed framing: 4-byte big-endian length + JSON body)

    func send(_ payload: NearbyTransferPayload) {
        guard !connections.isEmpty else { statusMessage = "No connected peers"; return }
        let envelope = TransferEnvelope(senderName: deviceName, payload: payload)
        guard let body = try? JSONEncoder().encode(envelope) else {
            statusMessage = "Encode error"; return
        }
        isSending = true
        let frame = makeFrame(body)
        // All connections are started on the main queue, so their send completions
        // are also delivered on the main queue — no synchronisation needed for
        // the counter or the @Published properties.
        let group = DispatchGroup()
        var firstError: String?
        for conn in connections {
            group.enter()
            conn.send(content: frame, completion: .contentProcessed { error in
                if let error, firstError == nil {
                    firstError = error.localizedDescription
                }
                group.leave()
            })
        }
        group.notify(queue: .main) { [weak self] in
            self?.isSending = false
            if let error = firstError {
                self?.statusMessage = "Send error: \(error)"
            } else {
                let names = self?.connectedPeerNames.joined(separator: ", ") ?? "device"
                self?.statusMessage = "Sent to \(names)"
            }
        }
    }

    /// Prepends a 4-byte big-endian length header to `data`.
    private func makeFrame(_ data: Data) -> Data {
        var bigEndian = UInt32(data.count).bigEndian
        return Data(bytes: &bigEndian, count: 4) + data
    }

    // MARK: - Receive loop

    private func receiveNextFrame(on conn: NWConnection, peerName: String) {
        // Step 1: read the 4-byte length header
        conn.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] header, _, isComplete, error in
            guard let self else { return }

            if error != nil || (isComplete && header == nil) {
                DispatchQueue.main.async {
                    self.connections.removeAll { $0 === conn }
                    self.connectedPeerNames.removeAll { $0 == peerName }
                }
                return
            }

            guard let header, header.count == 4 else { return }

            let length = header.withUnsafeBytes { UInt32(bigEndian: $0.load(as: UInt32.self)) }
            guard length > 0, length <= 10_000_000 else {
                // Malformed frame — keep receiving
                self.receiveNextFrame(on: conn, peerName: peerName)
                return
            }

            // Step 2: read `length` bytes of JSON body
            conn.receive(
                minimumIncompleteLength: Int(length),
                maximumLength: Int(length)
            ) { [weak self] body, _, _, _ in
                if let body,
                   let envelope = try? JSONDecoder().decode(TransferEnvelope.self, from: body) {
                    DispatchQueue.main.async {
                        self?.receivedPayload = envelope.payload
                        self?.receivedFromPeerName = envelope.senderName
                    }
                }
                // Continue reading the next frame
                self?.receiveNextFrame(on: conn, peerName: peerName)
            }
        }
    }

    func clearReceived() {
        receivedPayload = nil
        receivedFromPeerName = nil
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
                Label(manager.deviceName, systemImage: "laptopcomputer.and.iphone")
                if let status = manager.statusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Device-discovery section varies by platform and OS version
            deviceDiscoverySection

            if !manager.connectedPeerNames.isEmpty {
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
        // Received-data sheet (all platforms)
        .sheet(isPresented: Binding(
            get: { manager.receivedPayload != nil },
            set: { if !$0 { manager.clearReceived() } }
        )) {
            ReceivedTransferSheet(manager: manager)
        }
    }

    // MARK: - Adaptive device-discovery section

    @ViewBuilder
    private var deviceDiscoverySection: some View {
        #if os(tvOS)
        // tvOS: native SwiftUI DevicePicker (available since tvOS 16)
        systemPickerSection
        #else
        // iOS and macOS: custom NWBrowser peer list
        customBrowseSection
        #endif
    }

    /// Shows connected peers plus the native SwiftUI DevicePicker button (tvOS only).
    @ViewBuilder
    private var systemPickerSection: some View {
        #if os(tvOS)
        if #available(tvOS 16.0, *) {
            Section("Nearby Devices") {
                ForEach(manager.connectedPeerNames, id: \.self) { name in
                    Label(name, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                DevicePicker(
                    .applicationService(name: NearbyTransferManager.applicationServiceName)
                ) { endpoint in
                    manager.connect(to: endpoint)
                } label: {
                    Label("Browse for Devices…", systemImage: "wifi")
                } fallback: {
                    EmptyView()
                } parameters: {
                    .applicationService
                }
                .disabled(!manager.isActive)
            }
        }
        #endif
    }

    /// Shows NWBrowser-discovered peers in a list the user can tap to connect.
    @ViewBuilder
    private var customBrowseSection: some View {
        Section("Nearby Devices") {
            if !manager.isActive {
                Text("Tap Start to search for nearby devices")
                    .foregroundStyle(.secondary)
            } else if manager.discoveredPeers.isEmpty && manager.connectedPeerNames.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Searching…")
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(manager.discoveredPeers, id: \.name) { peer in
                HStack {
                    Label(peer.name, systemImage: "iphone.radiowaves.left.and.right")
                    Spacer()
                    Button("Connect") { manager.connect(to: peer.endpoint) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
            ForEach(manager.connectedPeerNames, id: \.self) { name in
                Label(name, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Helpers

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
                                    .filter { item in
                                        !existing.contains(where: { $0.urlString == item.urlString })
                                    }
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
