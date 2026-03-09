import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import WatchConnectivity
#endif

struct SettingsView: View {
    var body: some View {
        NavigationView {
            List {
                Section("Settings") {
                    NavigationLink {
                        AboutView()
                    } label: {
                        labelView(title: "About", symbol: "info.circle.fill", symbolBG: .gray, description: "About SchoolTool")
                    }
                    NavigationLink {
                        AppearanceSettings()
                    } label: {
                        labelView(title: "Appearance", symbol: "paintpalette.fill", symbolBG: .blue, description: "All Settings related to the Time Table")
                    }
                    NavigationLink {
                        ImportExportView()
                    } label: {
                        labelView(title: "Import/Export", symbol: "cloud.fill", symbolBG: .purple, description: "Import or Export Stuff")
                    }
#if os(iOS)
                    NavigationLink {
                        AppleWatchView()
                    } label: {
                        labelView(title: "Apple Watch", symbol: "applewatch", symbolBG: .green, description: WCSession.default.isWatchAppInstalled ? "Manage syncing to Watch" : "Watch App not Installed")
                    }
                    .disabled(!WCSession.default.isWatchAppInstalled)
#endif
                }
            }
        }
    }
    func icon(for symbol: String, color: Color) -> some View {
        Image(systemName: symbol)
            .scaledToFit()
            .frame(width: 10, height: 10)
            .foregroundStyle(.white)
            .font(.system(size: 15))
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .foregroundStyle(color)
            )
    }
    func labelView(title: LocalizedStringResource, symbol: String, symbolBG: Color, description: LocalizedStringResource) -> some View {
        HStack {
            icon(for: symbol, color: symbolBG)
            VStack(alignment: .leading) {
                Text(title)
                    .bold()
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    SettingsView()
}

#if os(iOS)
struct AppleWatchView: View {
    @StateObject var manager = TimeTableManager.shared
    var body: some View {
        Form {
            HStack {
                Spacer()
                ContentUnavailableView("SchoolTool watchOS", systemImage: "applewatch", description: Text("Version \(manager.watchAppVersionString ?? "-")"))
                Spacer()
            }
            Section("TimeTable Sync") {
                Button("Force Sync", systemImage: "arrow.trianglehead.2.clockwise.rotate.90") {
                    manager.sendToAppleWatch()
                }
                HStack {
                    Text("Last Synced")
                    Spacer()
                    Text(manager.lastSynced ?? "Never")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Apple Watch")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            if manager.waitingForVersionString {
                ProgressView()
                    .controlSize(.regular)
            } else {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    manager.requestAppVersionString()
                }
                .labelStyle(.iconOnly)
            }
        }
        .onAppear {
            manager.requestAppVersionString()
        }
    }
}
#endif

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    private var appBuild: String {
        if let buildString = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            " (\(buildString))"
        } else {
            ""
        }
    }
    
    var body: some View {
        Form {
            HStack {
                Spacer()
                ContentUnavailableView("SchoolTool", systemImage: "graduationcap.fill", description: Text("Version \(appVersion)\(appBuild)"))
                Spacer()
            }
            Section("Developer") {
                Link(destination: URL(string: "https://x.com/timi2506/")!) {
                    HStack {
                        Text("Twitter")
                        Spacer()
                        Text("@timi2506")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                Link(destination: URL(string: "https://github.com/timi2506/")!) {
                    HStack {
                        Text("GitHub")
                        Spacer()
                        Text("@timi2506")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("About")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

struct AppearanceSettings: View {
    @AppStorage("fullColorRow") var fullColorRow = false
    
    var body: some View {
        Form {
            HStack {
                Spacer()
                ContentUnavailableView("Appearance", systemImage: "paintpalette.fill", description: Text("Configure the Look and Feel of SchoolTool"))
                Spacer()
            }
            Section("TimeTable") {
                VStack(alignment: .leading) {
                    Toggle("Full Color Classes Rows", isOn: $fullColorRow)
                    Text("Whether to Color the Entire Classes Row in the Classes Color or just show a small colored dot")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Appearance")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

struct ImportExportView: View {
    @StateObject var timeTableManager = TimeTableManager.shared
    @State var importTimeTable = false
    @State var importError = false
    @State var importTimeTableObject: TimeTableSchedule?
    var body: some View {
        Form {
            HStack {
                Spacer()
                ContentUnavailableView("Import/Export", systemImage: "cloud.fill", description: Text("Import or Export Data for Backup or Sharing"))
                Spacer()
            }
            Section("TimeTable") {
#if os(iOS) || os(macOS)
                ShareLink("Export", item: makeBackupURL())
                    .buttonStyle(.plain)
                Button("Import", systemImage: "square.and.arrow.down") {
                    importTimeTable = true
                }
                .buttonStyle(.plain)
#endif
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Import/Export")
#if os(iOS) || os(macOS)
        .fileImporter(isPresented: $importTimeTable, allowedContentTypes: [.json]) { result in
            let decoder = JSONDecoder()
            if let url = try? result.get(), url.startAccessingSecurityScopedResource(), let data = try? Data(contentsOf: url), let decoded = try? decoder.decode(TimeTableSchedule.self, from: data) {
                url.stopAccessingSecurityScopedResource()
                importTimeTableObject = decoded
            } else {
                importError = true
            }
        }
#endif
        .alert("Error Importing", isPresented: $importError) {
            Button("OK", role: .cancel) { importError = false }
        } message: {
            Text("An Error occured trying to import, please try again.")
        }
        .alert("Import Selected TimeTable", isPresented: Binding(get: { importTimeTableObject != nil }, set: { _ = $0 })) {
            Button("Continue", role: .destructive) {
                timeTableManager.schedule = importTimeTableObject!
                importTimeTableObject = nil
            }
            Button("Cancel", role: .cancel) {
                importTimeTableObject = nil
            }
        } message: {
            Text("This will replace your current TimeTable and cannot be undone")
        }
    }
    func makeBackupURL() -> URL {
        let tempURL = URL.temporaryDirectory.appendingPathComponent("SchoolTool TimeTable - \(Date().formatted(date: .numeric, time: .shortened))", conformingTo: .json)
        let encoder = JSONEncoder()
        let data = try? encoder.encode(timeTableManager.schedule)
        try? data?.write(to: tempURL)
        return tempURL
    }
}
