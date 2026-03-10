//
//  Shared.swift
//  SchoolTool
//
//  Created by Tim on 09.03.26.
//

import Foundation
import SwiftUI
import Combine
import AppIntents

#if os(iOS) || os(watchOS)
import WatchConnectivity
#endif

#if canImport(Drops)
import Drops
#endif

#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - UserDefaults Shared Suite

extension UserDefaults {
    static var shared = UserDefaults(suiteName: "group.timi2506.SchoolTool2")!
}

// MARK: - Color+Codable

extension Color: @retroactive Codable {
    enum CodingKeys: String, CodingKey {
        case red, green, blue, alpha
        case cgColorComponents
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        #if os(iOS) || os(tvOS) || os(watchOS)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        let uiColor = UIColor(self)
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            try container.encode(Double(red), forKey: .red)
            try container.encode(Double(green), forKey: .green)
            try container.encode(Double(blue), forKey: .blue)
            try container.encode(Double(alpha), forKey: .alpha)
        } else {
            let cgColor = UIColor(self).cgColor
            let components = cgColor.components ?? []
            try container.encode(components, forKey: .cgColorComponents)
        }
        #elseif os(macOS)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        let nsColor = NSColor(self)
        if let rgbColor = nsColor.usingColorSpace(.deviceRGB) {
            rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            try container.encode(Double(red), forKey: .red)
            try container.encode(Double(green), forKey: .green)
            try container.encode(Double(blue), forKey: .blue)
            try container.encode(Double(alpha), forKey: .alpha)
        } else {
            let cgColor = NSColor(self).cgColor
            let components = cgColor.components ?? []
            try container.encode(components, forKey: .cgColorComponents)
        }
        #endif
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let red = try? container.decode(Double.self, forKey: .red),
           let green = try? container.decode(Double.self, forKey: .green),
           let blue = try? container.decode(Double.self, forKey: .blue),
           let alpha = try? container.decode(Double.self, forKey: .alpha) {
            self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
            return
        }
        if let cgComponentsDoubles = try? container.decode([Double].self, forKey: .cgColorComponents),
           cgComponentsDoubles.count >= 4 {
            self.init(.sRGB, red: cgComponentsDoubles[0], green: cgComponentsDoubles[1],
                      blue: cgComponentsDoubles[2], opacity: cgComponentsDoubles[3])
            return
        }
        self = .blue
    }
}

// MARK: - Models

struct TimeTableLesson: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var teacherName: String?
    var roomName: String?
    var symbol: String = "graduationcap"
    var color: Color
}

struct TimeTableSchedule: Identifiable, Codable, Hashable {
    var id = UUID()
    var days: [TimeTableDay]

    enum Days: String, CaseIterable, Codable, RawRepresentable, AppEnum {
        static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: "Day of the Week")

        static var caseDisplayRepresentations: [TimeTableSchedule.Days: DisplayRepresentation] = [
            .monday: DisplayRepresentation(title: "Monday"),
            .tuesday: DisplayRepresentation(title: "Tuesday"),
            .wednesday: DisplayRepresentation(title: "Wednesday"),
            .thursday: DisplayRepresentation(title: "Thursday"),
            .friday: DisplayRepresentation(title: "Friday"),
            .saturday: DisplayRepresentation(title: "Saturday"),
            .sunday: DisplayRepresentation(title: "Sunday")
        ]

        case monday
        case tuesday
        case wednesday
        case thursday
        case friday
        case saturday
        case sunday

        var name: LocalizedStringResource {
            switch self {
            case .monday:    "Monday"
            case .tuesday:   "Tuesday"
            case .wednesday: "Wednesday"
            case .thursday:  "Thursday"
            case .friday:    "Friday"
            case .saturday:  "Saturday"
            case .sunday:    "Sunday"
            }
        }

        var id: String { rawValue }

        var tomorrow: Days {
            switch self {
            case .monday:    .tuesday
            case .tuesday:   .wednesday
            case .wednesday: .thursday
            case .thursday:  .friday
            case .friday:    .saturday
            case .saturday:  .sunday
            case .sunday:    .monday
            }
        }

        var yesterday: Days {
            switch self {
            case .monday:    .sunday
            case .tuesday:   .monday
            case .wednesday: .tuesday
            case .thursday:  .wednesday
            case .friday:    .thursday
            case .saturday:  .friday
            case .sunday:    .saturday
            }
        }

        static var today: Days {
            switch Calendar.current.component(.weekday, from: Date()) {
            case 1: return .sunday
            case 2: return .monday
            case 3: return .tuesday
            case 4: return .wednesday
            case 5: return .thursday
            case 6: return .friday
            case 7: return .saturday
            default: return .monday
            }
        }
        
        var nextOccurenceDate: Date {
            let calendar = Calendar.current
            
            let today = calendar.component(.weekday, from: Date())
            
            let target: Int = switch self {
            case .sunday: 1
            case .monday: 2
            case .tuesday: 3
            case .wednesday: 4
            case .thursday: 5
            case .friday: 6
            case .saturday: 7
            }
            
            let daysUntil = (target - today + 7) % 7
            
            return calendar.date(byAdding: .day, value: daysUntil, to: Date())!
        }
    }

    struct TimeTableDay: Codable, Hashable, Identifiable {
        var day: Days
        var classes: [ScheduleClass]
        var id: String { day.rawValue }
    }
}

struct ScheduleClass: Identifiable, Codable, Hashable {
    var id = UUID()
    var time: TimeTableTime
    var lesson: TimeTableLesson
    var forceDoubleLesson: Bool? = false
}

struct TimeTableTime: Identifiable, Codable, Hashable {
    var id = UUID()
    var day: TimeTableSchedule.Days = .monday
    var start: TimeOfDay
    var end: TimeOfDay

    var startDate: Date {
        get { start.asToday }
        set { start = TimeOfDay(from: newValue) }
    }
    var endDate: Date {
        get { end.asToday }
        set { end = TimeOfDay(from: newValue) }
    }
}

struct TimeOfDay: Codable, Hashable {
    var hour: Int   // 0...23
    var minute: Int // 0...59

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    init(from date: Date) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        self.hour = comps.hour ?? 0
        self.minute = comps.minute ?? 0
    }

    var asToday: Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return cal.date(byAdding: .minute, value: hour * 60 + minute, to: today) ?? today
    }
}

// MARK: - WCSyncLogEntry

struct WCSyncLogEntry: Identifiable {
    enum Direction { case sent, received }

    let id = UUID()
    let date: Date
    let direction: Direction
    /// Short user-readable title, e.g. "Sent Schedule to Watch"
    let title: String
    /// Human-readable description of the payload content
    let detail: String
}

// MARK: - TimeTableManager

#if os(iOS)
/// Class Holding All TimeTable Data
class TimeTableManager: NSObject, ObservableObject, WCSessionDelegate {

    // MARK: WCSessionDelegate (required on iOS)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("WCSession activated: \(activationState.rawValue)")
        }
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }

    /// Shared TimeTable Manager
    static let shared = TimeTableManager()
    private var cancellables = Set<AnyCancellable>()

    private override init() {
        if let data = UserDefaults.shared.data(forKey: "schoolToolSchedule"),
           let existing = try? JSONDecoder().decode(TimeTableSchedule.self, from: data) {
            self.schedule = existing
        }
        super.init()
        #if canImport(Drops)
        // iOS main app: set up WatchConnectivity for syncing to Apple Watch
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        #else
        // iOS widget extension: observe UserDefaults changes for auto-reload
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: UserDefaults.shared)
            .sink { [weak self] _ in
                guard let self else { return }
                let data = UserDefaults.shared.data(forKey: "schoolToolSchedule") ?? Data()
                self.decodeAndPublish(from: data)
            }
            .store(in: &cancellables)
        #endif
    }

    @Published var schedule: TimeTableSchedule? {
        didSet {
            #if canImport(Drops)
            save()
            #endif
        }
    }
    @Published var watchAppVersionString: String?
    @Published var waitingForVersionString = false
    @Published var syncLog: [WCSyncLogEntry] = []
    @AppStorage("watchLastSynced") var lastSynced: String?

    // MARK: Log helper
    private func appendLog(_ entry: WCSyncLogEntry) {
        DispatchQueue.main.async {
            self.syncLog.insert(entry, at: 0)
            if self.syncLog.count > 100 {
                self.syncLog = Array(self.syncLog.prefix(100))
            }
        }
    }

    #if canImport(Drops)
    func save() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(schedule) {
            UserDefaults.shared.set(encoded, forKey: "schoolToolSchedule")
            sendToAppleWatch(encoded)
        }
    }

    func requestAppVersionString() {
        watchAppVersionString = nil
        waitingForVersionString = true
        let messageDict = ["request": "appVersionString"]
        let channel = WCSession.default.isReachable ? "sendMessage" : "transferUserInfo"
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(messageDict, replyHandler: nil) { error in
                print("Failed to send message", error.localizedDescription)
            }
        } else {
            WCSession.default.transferUserInfo(messageDict)
        }
        appendLog(WCSyncLogEntry(
            date: Date(),
            direction: .sent,
            title: "Requested Watch App Version",
            detail: "Key: \"request\" = \"appVersionString\" via \(channel)"
        ))
    }

    @available(iOS 18, *)
    func sendToAppleWatch(_ data: Data? = nil) {
        let encoder = JSONEncoder()
        guard let encodedSchedule = data ?? (try? encoder.encode(schedule)) else { return }
        var errorOccurred = false
        WCSession.default.outstandingUserInfoTransfers.forEach({ $0.cancel() })
        let messageDict = ["timetable_schedule": encodedSchedule]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(messageDict, replyHandler: nil) { error in
                print("Failed to send message:", error.localizedDescription)
                errorOccurred = true
            }
            let drop = Drop(
                title: "Schedule Synced to Watch",
                subtitle: "Apple Watch synced successfully",
                icon: UIImage(systemName: "checkmark.circle.fill")!,
                position: .top
            )
            if !errorOccurred {
                Drops.hideAll()
                Drops.show(drop)
                lastSynced = Date().formatted(date: .long, time: .shortened)
            }
        } else {
            WCSession.default.transferUserInfo(messageDict)
            let drop = Drop(
                title: "Schedule will Sync to Watch",
                subtitle: "When connected",
                icon: UIImage(systemName: "checkmark.circle.fill")!,
                position: .top
            )
            if !errorOccurred {
                Drops.hideAll()
                Drops.show(drop)
                lastSynced = Date().formatted(date: .long, time: .shortened)
            }
        }
        let channel = WCSession.default.isReachable ? "sendMessage" : "transferUserInfo"
        let dayCount = schedule?.days.count ?? 0
        let classCount = schedule?.days.reduce(0) { $0 + $1.classes.count } ?? 0
        appendLog(WCSyncLogEntry(
            date: Date(),
            direction: .sent,
            title: "Sent Schedule to Watch",
            detail: "\(dayCount) day(s), \(classCount) class(es), \(encodedSchedule.count) bytes via \(channel)"
        ))
    }
    #endif

    private func decodeAndPublish(from data: Data) {
        guard !data.isEmpty else {
            if schedule != nil { schedule = nil }
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
            return
        }
        if let decoded = try? JSONDecoder().decode(TimeTableSchedule.self, from: data),
           decoded != schedule {
            schedule = decoded
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
    }

    // MARK: WCSession receiving (iOS main app receives requests from Watch)
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let request = message["request"] as? String {
            DispatchQueue.main.async {
                switch request {
                case "timetable_schedule":
                    self.appendLog(WCSyncLogEntry(
                        date: Date(),
                        direction: .received,
                        title: "Watch Requested Schedule",
                        detail: "Key: \"request\" = \"timetable_schedule\" via sendMessage"
                    ))
                    #if canImport(Drops)
                    self.sendToAppleWatch()
                    #endif
                default:
                    print("Unknown Request")
                }
            }
        } else if let appVersionString = message["appVersionString"] as? String {
            DispatchQueue.main.async {
                self.watchAppVersionString = appVersionString
                self.waitingForVersionString = false
                self.appendLog(WCSyncLogEntry(
                    date: Date(),
                    direction: .received,
                    title: "Received Watch App Version",
                    detail: "Version: \(appVersionString) via sendMessage"
                ))
            }
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let request = userInfo["request"] as? String {
            DispatchQueue.main.async {
                switch request {
                case "timetable_schedule":
                    self.appendLog(WCSyncLogEntry(
                        date: Date(),
                        direction: .received,
                        title: "Watch Requested Schedule",
                        detail: "Key: \"request\" = \"timetable_schedule\" via transferUserInfo"
                    ))
                    #if canImport(Drops)
                    self.sendToAppleWatch()
                    #endif
                default:
                    print("Unknown Request")
                }
            }
        } else if let appVersionString = userInfo["appVersionString"] as? String {
            DispatchQueue.main.async {
                self.watchAppVersionString = appVersionString
                self.waitingForVersionString = false
                self.appendLog(WCSyncLogEntry(
                    date: Date(),
                    direction: .received,
                    title: "Received Watch App Version",
                    detail: "Version: \(appVersionString) via transferUserInfo"
                ))
            }
        }
    }
}

#elseif os(watchOS)
/// Class Holding All TimeTable Data
class TimeTableManager: NSObject, ObservableObject, WCSessionDelegate {

    /// Shared TimeTable Manager
    static let shared = TimeTableManager()
    private var cancellables = Set<AnyCancellable>()

    // WidgetKit extensions always have a .appex bundle; the main app has .app.
    private let isWidgetExtension = Bundle.main.bundleURL.pathExtension == "appex"

    private override init() {
        if let data = UserDefaults.shared.data(forKey: "schoolToolSchedule"),
           let existing = try? JSONDecoder().decode(TimeTableSchedule.self, from: data) {
            self.schedule = existing
        }
        super.init()
        if !isWidgetExtension {
            // Watch main app: set up WatchConnectivity to receive schedule from iPhone
            if WCSession.isSupported() {
                WCSession.default.delegate = self
                WCSession.default.activate()
            }
            request()
        } else {
            // Watch widget extension: observe UserDefaults changes for auto-reload
            NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: UserDefaults.shared)
                .sink { [weak self] _ in
                    guard let self else { return }
                    let data = UserDefaults.shared.data(forKey: "schoolToolSchedule") ?? Data()
                    self.decodeAndPublish(from: data)
                }
                .store(in: &cancellables)
        }
    }

    @Published var schedule: TimeTableSchedule?
    @Published var awaitingSync = false

    func request() {
        WCSession.default.outstandingUserInfoTransfers.forEach({ $0.cancel() })
        awaitingSync = true
        let messageDict = ["request": "timetable_schedule"]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(messageDict, replyHandler: nil) { error in
                print("Failed to send message:", error.localizedDescription)
            }
        } else {
            WCSession.default.transferUserInfo(messageDict)
        }
    }

    private func decodeAndPublish(from data: Data) {
        guard !data.isEmpty else {
            if schedule != nil { schedule = nil }
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
            return
        }
        if let decoded = try? JSONDecoder().decode(TimeTableSchedule.self, from: data),
           decoded != schedule {
            schedule = decoded
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
    }

    func sendVersionString() {
        let info = Bundle.main.infoDictionary
        let version = (info?["CFBundleShortVersionString"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let build = (info?["CFBundleVersion"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = (version?.isEmpty == false) ? version! : "Unknown"
        let formatted = (build?.isEmpty == false) ? "\(base)(\(build!))" : base
        let payload: [String: Any] = ["appVersionString": formatted]
        if WCSession.isSupported() {
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(payload, replyHandler: nil) { error in
                    print("Failed to send appVersionString:", error.localizedDescription)
                }
            } else {
                WCSession.default.transferUserInfo(payload)
            }
        }
    }

    // MARK: WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("WCSession activated: \(activationState.rawValue)")
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let decoder = JSONDecoder()
        if let encodedJSON = message["timetable_schedule"] as? Data,
           let decodedSchedule = try? decoder.decode(TimeTableSchedule.self, from: encodedJSON) {
            DispatchQueue.main.async {
                self.schedule = decodedSchedule
                UserDefaults.shared.set(encodedJSON, forKey: "schoolToolSchedule")
                self.awaitingSync = false
            }
        } else if let request = message["request"] as? String {
            DispatchQueue.main.async {
                switch request {
                case "appVersionString": self.sendVersionString()
                default: print("Unknown Request")
                }
            }
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let decoder = JSONDecoder()
        if let encodedJSON = userInfo["timetable_schedule"] as? Data,
           let decodedSchedule = try? decoder.decode(TimeTableSchedule.self, from: encodedJSON) {
            DispatchQueue.main.async {
                self.schedule = decodedSchedule
                UserDefaults.shared.set(encodedJSON, forKey: "schoolToolSchedule")
                self.awaitingSync = false
            }
        } else if let request = userInfo["request"] as? String {
            DispatchQueue.main.async {
                switch request {
                case "appVersionString": self.sendVersionString()
                default: print("Unknown Request")
                }
            }
        }
    }
}

#else
/// Class Holding All TimeTable Data (macOS / tvOS)
class TimeTableManager: ObservableObject {
    /// Shared TimeTable Manager
    static let shared = TimeTableManager()

    init() {
        if let data = UserDefaults.shared.data(forKey: "schoolToolSchedule"),
           let existing = try? JSONDecoder().decode(TimeTableSchedule.self, from: data) {
            self.schedule = existing
        }
    }

    @Published var schedule: TimeTableSchedule? {
        didSet { save() }
    }

    func save() {
        if let encoded = try? JSONEncoder().encode(schedule) {
            UserDefaults.shared.set(encoded, forKey: "schoolToolSchedule")
        }
    }
}
#endif

// MARK: - Current / Next Class Helpers (used by widgets and shortcuts)

extension TimeTableManager {
    var currentClass: ScheduleClass? {
        currentClass(at: Date())
    }
    /// Returns the class currently ongoing at the given date, if any.
    func currentClass(at date: Date = Date()) -> ScheduleClass? {
        guard let schedule else { return nil }
        let day = TimeTableSchedule.Days.today
        let classes = schedule.days.first(where: { $0.day == day })?.classes ?? []
        return classes.first(where: { cls in
            let start = cls.time.start.asToday
            let end = cls.time.end.asToday
            return (start...end).contains(date)
        })
    }

    /// Returns the soonest upcoming class after the given date (searches today then following days).
    func nextClass(after date: Date = Date()) -> ScheduleClass? {
        guard let schedule else { return nil }
        let today = TimeTableSchedule.Days.today

        func sortedClasses(for day: TimeTableSchedule.Days) -> [ScheduleClass] {
            (schedule.days.first(where: { $0.day == day })?.classes ?? [])
                .sorted { $0.time.start.asToday < $1.time.start.asToday }
        }

        if let upcomingToday = sortedClasses(for: today).first(where: { $0.time.start.asToday > date }) {
            return upcomingToday
        }

        var day = today.tomorrow
        for _ in 0..<6 {
            if let first = sortedClasses(for: day).first { return first }
            day = day.tomorrow
        }
        return nil
    }

    /// Returns the current class if one is in progress, otherwise the next upcoming class.
    func currentOrNextClass(at date: Date = Date()) -> ScheduleClass? {
        currentClass(at: date) ?? nextClass(after: date)
    }
}
