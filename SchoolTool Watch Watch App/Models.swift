import SwiftUI
import Combine
import WatchConnectivity

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
    
    enum Days: String, CaseIterable, Codable, RawRepresentable {
        case monday
        case tuesday
        case wednesday
        case thursday
        case friday
        case saturday
        case sunday
        var name: LocalizedStringResource {
            switch self {
                case .monday:
                    "Monday"
                case .tuesday:
                    "Tuesday"
                case .wednesday:
                    "Wednesday"
                case .thursday:
                    "Thursday"
                case .friday:
                    "Friday"
                case .saturday:
                    "Saturday"
                case .sunday:
                    "Sunday"
            }
        }
        var id: String {
            return self.rawValue
        }
        var tomorrow: Days {
            switch self {
                case .monday:
                    return .tuesday
                case .tuesday:
                    return .wednesday
                case .wednesday:
                    return .thursday
                case .thursday:
                    return .friday
                case .friday:
                    return .saturday
                case .saturday:
                    return .sunday
                case .sunday:
                    return .monday
            }
        }
        var yesterday: Days {
            switch self {
                case .monday:
                    return .sunday
                case .tuesday:
                    return .monday
                case .wednesday:
                    return .tuesday
                case .thursday:
                    return .wednesday
                case .friday:
                    return .thursday
                case .saturday:
                    return .friday
                case .sunday:
                    return .saturday
            }
        }
        static var today: Days {
            let weekday = Calendar.current.component(.weekday, from: Date())
            
            switch weekday {
                case 1: return .sunday
                case 2: return .monday
                case 3: return .tuesday
                case 4: return .wednesday
                case 5: return .thursday
                case 6: return .friday
                case 7: return .saturday
                default:
                    return .monday
            }
        }
    }
    struct TimeTableDay: Codable, Hashable, Identifiable {
        var day: Days
        var classes: [ScheduleClass]
        var id: String {
            return day.rawValue
        }
    }
}

struct ScheduleClass: Identifiable, Codable, Hashable {
    var id = UUID()
    var time: TimeTableTime
    var lesson: TimeTableLesson
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

/// Class Holding All TimeTable Data
class TimeTableManager: NSObject, ObservableObject, WCSessionDelegate {
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("WCSession activated: \(activationState.rawValue)")
        }
    }
    
    /// Shared TimeTable Manager
    static let shared = TimeTableManager()
    /// Use Shared Manager Instead
    private override init() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.shared.data(forKey: "schoolToolSchedule"), let existing = try? decoder.decode(TimeTableSchedule.self, from: data) {
            self.schedule = existing
        }
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        request()
    }
    @Published var schedule: TimeTableSchedule?
    @Published var awaitingSync = false
    
    func request() {
        // Remove all pending first
        WCSession.default.outstandingUserInfoTransfers.forEach({ $0.cancel() })
        awaitingSync = true
        let messageDict = ["request": "timetable_schedule"]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(messageDict, replyHandler: nil) { error in
                print("Failed to send message:", error.localizedDescription)
            }
        } else {
            // fallback: send as background transfer
            WCSession.default.transferUserInfo(messageDict)
        }
    }
    
    // Receiving messages
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        let decoder = JSONDecoder()
        if let encodedJSON = message["timetable_schedule"] as? Data, let decodedSchedule = try? decoder.decode(TimeTableSchedule.self, from: encodedJSON) {
            DispatchQueue.main.async {
                self.schedule = decodedSchedule
                UserDefaults.shared.set(encodedJSON, forKey: "schoolToolSchedule")
                self.awaitingSync = false
            }
        } else if let request = message["request"] as? String {
            DispatchQueue.main.async {
                switch request {
                    case "appVersionString": self.sendVersionString()
                    default:
                        print("Unknown Request")
                }
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        let decoder = JSONDecoder()
        if let encodedJSON = userInfo["timetable_schedule"] as? Data, let decodedSchedule = try? decoder.decode(TimeTableSchedule.self, from: encodedJSON) {
            DispatchQueue.main.async {
                self.schedule = decodedSchedule
                UserDefaults.shared.set(encodedJSON, forKey: "schoolToolSchedule")
                self.awaitingSync = false
            }
        } else if let request = userInfo["request"] as? String {
            DispatchQueue.main.async {
                switch request {
                    case "appVersionString": self.sendVersionString()
                    default:
                        print("Unknown Request")
                }
            }
        }
    }
    
    func sendVersionString() {
        let info = Bundle.main.infoDictionary
        let version = (info?["CFBundleShortVersionString"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let build = (info?["CFBundleVersion"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        let base = (version?.isEmpty == false) ? version! : "Unknown"
        let formatted: String
        if let build = build, !build.isEmpty {
            formatted = "\(base)(\(build))"
        } else {
            formatted = base
        }

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
}

extension UserDefaults {
    static var shared = UserDefaults(suiteName: "group.timi2506.SchoolTool")!
}
