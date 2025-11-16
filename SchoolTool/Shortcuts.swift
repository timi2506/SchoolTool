import AppIntents
import SwiftUI

struct NextClassIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Class"
    static var description: IntentDescription? = .init("Gets the Current or Next Class", searchKeywords: ["Current Class", "Next Class"])
    
    func perform() async throws -> some IntentResult & ReturnsValue<ScheduleClassEntity?> {
        if let currentOrNextClass = await currentOrNextClass(at: Date()) {
            let entity = ScheduleClassEntity(from: currentOrNextClass)
                return .result(value: entity)
        } else {
            return .result(value: nil)
        }
    }
}

struct ClassIntent: AppIntent {
    static var title: LocalizedStringResource = "Class"
    static var description: IntentDescription? = .init("Gets the Current or Next Class", searchKeywords: ["Class"])
    static var parameterSummary: some ParameterSummary {
        Summary("Return \(\.$class)")
    }
    @Parameter(title: "Class", optionsProvider: DynamicScheduleClassEntityProvider()) var `class`: ScheduleClassEntity
    func perform() async throws -> some IntentResult & ReturnsValue<ScheduleClassEntity> {
        return .result(value: `class`)
    }
}

struct DynamicScheduleClassEntityProvider: DynamicOptionsProvider {
    func defaultResult() async -> ScheduleClassEntity? {
        if let currentOrNext = currentOrNextClass() {
            return ScheduleClassEntity(from: currentOrNext)
        }
        return nil
    }
    func results() async -> [ScheduleClassEntity] {
        var lessons: [ScheduleClass] = []
        let lessonArrays = TimeTableManager.shared.schedule?.days.compactMap({ $0.classes.map({ $0 }) })
        lessonArrays?.forEach({ lessons.append(contentsOf: $0) })
        
        return lessons.compactMap({ ScheduleClassEntity(from: $0) })
    }
}

struct TimeTableLessonEntity: AppEntity, Identifiable {
    static var defaultQuery: TimeTableLessonEntityQuery = TimeTableLessonEntityQuery()
    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: "TimeTable Lesson")
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(makeSubtitleString())",
            image: .init(systemName: symbol)
        )
    }
    var id: UUID
    @Property(title: "Name") var name: String
    @Property(title: "Teacher Name") var teacherName: String?
    @Property(title: "Room Name") var roomName: String?
    var symbol: String = "graduationcap"
    var color: Color = .blue
    func makeSubtitleString() -> String {
        let teacherString = (teacherName == nil) ? "" : "\(teacherName!)"
        let roomString = (roomName == nil) ? "" : teacherName == nil ? roomName! : "• Room \(roomName!)"
        return "\(teacherString)\(roomString)"
    }
    var asTimeTableLesson: TimeTableLesson {
        TimeTableLesson(id: id, name: name, teacherName: teacherName, roomName: roomName, symbol: symbol, color: color)
    }
    init(from timeTableLesson: TimeTableLesson) {
        self.id = timeTableLesson.id
        self.name = timeTableLesson.name
        self.teacherName = timeTableLesson.teacherName
        self.roomName = timeTableLesson.roomName
        self.symbol = timeTableLesson.symbol
        self.color = timeTableLesson.color
    }
}

struct TimeTableLessonEntityQuery: EntityQuery {
    typealias Entity = TimeTableLessonEntity
    func suggestedEntities() async throws -> [Entity] {
        var lessons: [TimeTableLesson] = []
        let lessonArrays = await TimeTableManager.shared.schedule?.days.compactMap({ $0.classes.map({ $0.lesson }) })
        lessonArrays?.forEach({ lessons.append(contentsOf: $0) })
        return lessons.compactMap({ TimeTableLessonEntity(from: $0) })
    }
    func entities(for identifiers: [Entity.ID]) async throws -> [Entity] {
        var lessons: [TimeTableLesson] = []
        let lessonArrays = await TimeTableManager.shared.schedule?.days.compactMap({ $0.classes.map({ $0.lesson }) })
        lessonArrays?.forEach({ lessons.append(contentsOf: $0) })
        
        return lessons.compactMap({ TimeTableLessonEntity(from: $0) }).filter({ identifiers.contains($0.id) })
    }
}

struct ScheduleClassEntity: Identifiable, AppEntity {
    init(from scheduleClass: ScheduleClass) {
        self.id = scheduleClass.id
        self.time = scheduleClass.time
        self.lesson = TimeTableLessonEntity(from: scheduleClass.lesson)
    }
    static var defaultQuery: ScheduleClassEntityQuery = ScheduleClassEntityQuery()
    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: "Schedule Class")
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(lesson.name)",
            subtitle: "\(makeSubtitleString())",
            image: .init(systemName: lesson.symbol)
        )
    }
    
    var id = UUID()
    var time: TimeTableTime
    @Property(title: "Lesson") var lesson: TimeTableLessonEntity
    var asScheduleClass: ScheduleClass {
        return ScheduleClass(id: id, time: time, lesson: lesson.asTimeTableLesson)
    }
    func timeString(_ time: TimeTableTime) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(formatter.string(from: time.startDate)) – \(formatter.string(from: time.endDate))"
    }
    func makeSubtitleString() -> String {
        let timeString = "\(timeString(time))"
        let dayString = " • \(String(localized: self.time.day.name))"
        let teacherString = (lesson.teacherName == nil) ? "" : " • \(lesson.teacherName!)"
        let roomString = (lesson.roomName == nil) ? "" : " • Room \(lesson.roomName!)"
        return "\(timeString)\(dayString)\(teacherString)\(roomString)"
    }
}

struct ScheduleClassEntityQuery: EntityQuery {
    typealias Entity = ScheduleClassEntity
    func suggestedEntities() async throws -> some ResultsCollection {
        var lessons: [ScheduleClass] = []
        let lessonArrays = await TimeTableManager.shared.schedule?.days.compactMap({ $0.classes.map({ $0 }) })
        lessonArrays?.forEach({ lessons.append(contentsOf: $0) })
        
        return lessons.compactMap({ ScheduleClassEntity(from: $0) })
    }
    func entities(for identifiers: [Entity.ID]) async throws -> [Entity] {
        var lessons: [ScheduleClass] = []
        let lessonArrays = await TimeTableManager.shared.schedule?.days.compactMap({ $0.classes.map({ $0 }) })
        lessonArrays?.forEach({ lessons.append(contentsOf: $0) })
        
        return lessons.compactMap({ ScheduleClassEntity(from: $0) }).filter({ identifiers.contains($0.id) })
    }
}

func currentClass(at date: Date = Date()) -> ScheduleClass? {
    guard let schedule = TimeTableManager.shared.schedule else { return nil }
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
    guard let schedule = TimeTableManager.shared.schedule else { return nil }
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

