import WidgetKit
import SwiftUI

struct TimeTableEntry: TimelineEntry {
    var date: Date
    var item: ScheduleClass?
}

struct TimeTableTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimeTableEntry {
        if context.isPreview {
            let demoTime = TimeTableTime(day: .friday, start: .init(hour: 9, minute: 41), end: .init(hour: 10, minute: 41))
            let demoLesson = TimeTableLesson(name: "Keynote", teacherName: "Steve Jobs", roomName: "Macworld Conference & Expo", symbol: "iphone", color: .purple)
            let demoClass = ScheduleClass(time: demoTime, lesson: demoLesson)
            return TimeTableEntry(date: .iphoneReleaseDate, item: demoClass)
        } else {
            return TimeTableEntry(date: Date())
        }
    }
    func getSnapshot(in context: Context, completion: @escaping (TimeTableEntry) -> Void) {
        let entry = TimeTableEntry(date: Date(), item: TimeTableManager.shared.currentOrNextClass(at: Date()))
        completion(entry)
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TimeTableEntry>) -> Void) {
        let currentDate = Date()
        let entry = TimeTableEntry(date: currentDate, item: TimeTableManager.shared.currentOrNextClass(at: currentDate))
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct TimeTableWidgetView: View {
    var entry: TimeTableEntry
    @Environment(\.widgetFamily) var widgetFamily
    @Environment(\.widgetRenderingMode) var widgetRenderingMode
    @Environment(\.showsWidgetContainerBackground) var showsContainerBackground

    var body: some View {
        if let item = entry.item {
            Group {
                switch widgetFamily {
                    case .accessoryCorner: accessoryCorner(item)
                    case .accessoryInline: accessoryInline(item)
                    case .accessoryCircular: accessoryCircular(item)
                    case .accessoryRectangular: accessoryRectangular(item)
                    default:
                        Text("?")
                }
            }
            .containerBackground(LinearGradient(colors: [item.lesson.color.opacity(0.25), item.lesson.color.opacity(0.75)], startPoint: .top, endPoint: .bottom), for: .widget)
            .widgetAccentable()
        } else {
            Group {
                switch widgetFamily {
                    case .accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular: unavailable()
                    default:
                        Text("?")
                }
            }
            .containerBackground(LinearGradient(colors: [.primary.opacity(0.25), .primary.opacity(0.75)], startPoint: .top, endPoint: .bottom), for: .widget)
            .widgetAccentable()
        }
    }
    func timeString(_ time: TimeTableTime) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(formatter.string(from: time.startDate)) – \(formatter.string(from: time.endDate))"
    }
    func accessoryCorner(_ item: ScheduleClass) -> some View {
        Text(item.lesson.name)
            .widgetCurvesContent(true)
            .widgetLabel {
                Text(timeString(item.time))
            }
    }
    func accessoryInline(_ item: ScheduleClass) -> some View {
        HStack {
            Image(systemName: item.lesson.symbol)
                .foregroundStyle(item.lesson.color)
            Text(item.lesson.name)
        }
    }
    func accessoryCircular(_ item: ScheduleClass) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack {
                HStack(spacing: 1.5) {
                    Image(systemName: item.lesson.symbol)
                        .foregroundStyle(item.lesson.color)
                        .font(.system(size: 7.5))
                    Text(item.lesson.name)
                        .font(.system(size: 7.5))
                        .bold()
                        .lineLimit(3)
                }
                .padding(.horizontal, 5)
                if let room = item.lesson.roomName {
                    Text(room)
                        .lineLimit(1)
                        .font(.system(size: 7.5))
                }
            }
        }
    }
    func accessoryRectangular(_ item: ScheduleClass) -> some View {
        HStack {
            VStack {
                Image(systemName: item.lesson.symbol)
                    .font(.system(size: 25))
                if let room = item.lesson.roomName {
                    Text(room)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading) {
                Text(item.lesson.name)
                    .font(.body)
                    .bold()
                Text(timeString(item.time))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let teacher = item.lesson.teacherName {
                    Text(teacher)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(showsContainerBackground || widgetRenderingMode == .accented ? AnyShapeStyle(.primary) : AnyShapeStyle(LinearGradient(colors: [item.lesson.color.opacity(0.25), item.lesson.color.opacity(0.75)], startPoint: .top, endPoint: .bottom)))
    }
    func unavailable() -> some View {
        Text("No Schedule set")
            .widgetCurvesContent(true)
    }
}

#Preview(as: .accessoryRectangular) {
    TimeTableWidget()
} timeline: {
    TimeTableEntry(date: Date(), item: .init(time: .init(start: .init(hour: 9, minute: 41), end: .init(hour: 10, minute: 41)), lesson: .init(name: "Mathe", color: .blue)))
}


struct TimeTableWidget: Widget {
    let kind = "TimeTableWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimeTableTimelineProvider()) { entry in
            TimeTableWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Class")
        .description("Updates every minute.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
    }
}

extension Date {
    static var iphoneReleaseDate: Date {
        var components = DateComponents()
        components.year = 2007
        components.month = 6
        components.day = 29
        components.hour = 9
        components.minute = 41
        components.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        
        return Calendar.current.date(from: components)!
    }
}
