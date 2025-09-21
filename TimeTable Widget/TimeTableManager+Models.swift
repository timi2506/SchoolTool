import SwiftUI
import Combine
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Class Holding All TimeTable Data
class TimeTableManager: ObservableObject {
    
    // Mirror of the stored JSON to leverage @AppStorage-like updates
    @AppStorage("schoolToolSchedule", store: UserDefaults.shared)
    private var storedScheduleData: Data = Data() {
        didSet {
            // Decode and publish whenever the data changes
            decodeAndPublish(from: storedScheduleData)
        }
    }

    private var cancellables = Set<AnyCancellable>()
    
    /// Shared TimeTable Manager
    static let shared = TimeTableManager()
    /// Use Shared Manager Instead
    init() {
        // Attempt initial load from UserDefaults
        let decoder = JSONDecoder()
        if let data = UserDefaults.shared.data(forKey: "schoolToolSchedule"),
           let existing = try? decoder.decode(TimeTableSchedule.self, from: data) {
            self.schedule = existing
        }

        // Observe cross-process/defaults changes to keep in sync
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: UserDefaults.shared)
            .sink { [weak self] _ in
                guard let self else { return }
                let data = UserDefaults.shared.data(forKey: "schoolToolSchedule") ?? Data()
                self.decodeAndPublish(from: data)
            }
            .store(in: &cancellables)
    }
    @Published var schedule: TimeTableSchedule?
    
    // MARK: - Encoding / Decoding
    private func decodeAndPublish(from data: Data) {
        guard !data.isEmpty else {
            if schedule != nil { schedule = nil }
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
            return
        }
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode(TimeTableSchedule.self, from: data) {
            if decoded != schedule {
                schedule = decoded
                #if canImport(WidgetKit)
                WidgetCenter.shared.reloadAllTimelines()
                #endif
            }
        }
    }

    // MARK: - Current / Next Class Helpers
    /// Returns the class that is currently ongoing at the given date, if any.
    func currentClass(at date: Date = Date()) -> ScheduleClass? {
        guard let schedule else { return nil }
        let day = TimeTableSchedule.Days.today
        let classes = schedule.days.first(where: { $0.day == day })?.classes ?? []
        return classes.first(where: { cls in
            let start = cls.time.start.asToday
            let end = cls.time.end.asToday
            return (start ... end).contains(date)
        })
    }

    /// Returns the soonest upcoming class after the given date (searches today then following days).
    func nextClass(after date: Date = Date()) -> ScheduleClass? {
        guard let schedule else { return nil }
        let today = TimeTableSchedule.Days.today

        // Helper to map a day to its classes sorted by start time
        func sortedClasses(for day: TimeTableSchedule.Days) -> [ScheduleClass] {
            let classes = schedule.days.first(where: { $0.day == day })?.classes ?? []
            return classes.sorted { lhs, rhs in
                lhs.time.start.asToday < rhs.time.start.asToday
            }
        }

        // 1) Check remaining classes today
        let todayClasses = sortedClasses(for: today)
        if let upcomingToday = todayClasses.first(where: { $0.time.start.asToday > date }) {
            return upcomingToday
        }

        // 2) Look ahead up to 6 days
        var day = today.tomorrow
        for _ in 0..<6 {
            let classes = sortedClasses(for: day)
            if let first = classes.first { return first }
            day = day.tomorrow
        }
        return nil
    }

    /// Returns the current class if one is in progress, otherwise the next upcoming class.
    func currentOrNextClass(at date: Date = Date()) -> ScheduleClass? {
        return currentClass(at: date) ?? nextClass(after: date)
    }
}

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

extension UserDefaults {
    static var shared = UserDefaults(suiteName: "group.timi2506.SchoolTool")!
}

