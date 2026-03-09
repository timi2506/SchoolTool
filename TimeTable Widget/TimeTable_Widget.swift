import WidgetKit
import SwiftUI
import AppIntents

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
    var body: some View {
        if let item = entry.item {
            switch widgetFamily {
                case .accessoryInline: accessoryInline(item)
                case .accessoryCircular: accessoryCircular(item)
                case .accessoryRectangular: accessoryRectangular(item)
                case .systemSmall, .systemMedium: smallMedium(item)
                case .systemLarge, .systemExtraLarge: largeExtraLarge(item)
                default:
                    Text("?")
            }
        } else {
            switch widgetFamily {
                case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge: systemSizeUnavailable()
                case .accessoryInline: accessoryInlineUnavailable()
                case .accessoryCircular: accessoryCircularUnavailable()
                case .accessoryRectangular: accessoryRectangularUnavailable()
                default:
                    Text("?")
            }
        }
    }
    func timeString(_ time: TimeTableTime) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(formatter.string(from: time.startDate)) – \(formatter.string(from: time.endDate))"
    }
    func accessoryInlineUnavailable() -> some View {
        Button(intent: RefreshWidgetsIntent()) {
            HStack {
                Image(systemName: "questionmark")
                Text("No Schedule")
            }
        }
        .buttonStyle(.plain)
    }
    func accessoryInline(_ item: ScheduleClass) -> some View {
        Button(intent: RefreshWidgetsIntent()) {
            HStack {
                Image(systemName: item.lesson.symbol)
                Text(item.lesson.name)
            }
        }
        .buttonStyle(.plain)
    }
    func accessoryCircularUnavailable() -> some View {
        Button(intent: RefreshWidgetsIntent()) {
            VStack {
                Text("No")
                    .font(.system(size: 10))
                    .bold()
                    .lineLimit(1)
                Image(systemName: "questionmark")
                    .font(.title)
                Text("Schedule")
                    .font(.system(size: 10))
            }
        }
        .buttonStyle(.plain)
    }
    func accessoryCircular(_ item: ScheduleClass) -> some View {
        Button(intent: RefreshWidgetsIntent()) {
            VStack {
                Text(item.lesson.name)
                    .font(.system(size: 10))
                    .bold()
                    .lineLimit(1)
                Image(systemName: item.lesson.symbol)
                    .font(.title)
                Text(timeString(item.time))
                    .font(.system(size: 7.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
    func accessoryRectangular(_ item: ScheduleClass) -> some View {
        ZStack {
            HStack {
                Image(systemName: item.lesson.symbol)
                    .font(.title)
                VStack(alignment: .leading) {
                    Text(item.lesson.name)
                        .bold()
                    Text(timeString(item.time))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    func accessoryRectangularUnavailable() -> some View {
        Button(intent: RefreshWidgetsIntent()) {
            HStack {
                Image(systemName: "questionmark")
                    .font(.title)
                VStack(alignment: .leading) {
                    Text("No Schedule")
                        .bold()
                    Text("Set one up first!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
    func systemSizeUnavailable() -> some View {
        Button(intent: RefreshWidgetsIntent()) {
            ContentUnavailableView("No Schedule", systemImage: "calendar", description: Text("Set one up first!"))
        }
        .buttonStyle(.plain)
    }
    func largeExtraLarge(_ item: ScheduleClass) -> some View {
        ZStack {
            VStack(alignment: .center) {
                Image(systemName: item.lesson.symbol)
                    .font(.largeTitle)
                    .foregroundStyle(.primary)
                VStack(alignment: .center) {
                    Text(item.lesson.name)
                        .bold()
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .font(.title)
                    Text(timeString(item.time))
                        .lineLimit(1)
                        .font(.body)
                        .bold()
                }
                Divider()
                HStack(alignment: .top) {
                    Image(systemName: "person")
                    Text(item.lesson.teacherName ?? "None Provided")
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
                .font(.body)
                Divider()
                HStack(alignment: .top) {
                    Image(systemName: "square.split.bottomrightquarter")
                    Text(item.lesson.roomName ?? "None Provided")
                        .lineLimit(2)
                }
                .foregroundStyle(.secondary)
                .font(.body)
            }
            .padding(.horizontal, -5)
            .containerBackground(LinearGradient(colors: [item.lesson.color.opacity(0.25), item.lesson.color.opacity(0.75)], startPoint: .top, endPoint: .bottom), for: .widget)
            Text(entry.date, format: .dateTime)
                .font(.system(size: 7.5))
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.bottom, -10)
            Button(intent: RefreshWidgetsIntent()) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("REFRESH")
                }
                .font(.system(size: 7.5))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, -10)
        }
    }
    func smallMedium(_ item: ScheduleClass) -> some View {
        ZStack {
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: item.lesson.symbol)
                        .font(.system(size: 30))
                        .foregroundStyle(.primary)
                    VStack(alignment: .leading) {
                        Text(item.lesson.name)
                            .bold()
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(timeString(item.time))
                            .lineLimit(1)
                            .font(.caption)
                            .bold()
                    }
                }
                
                Divider()
                HStack(alignment: .top) {
                    Image(systemName: "person")
                    Text(item.lesson.teacherName ?? "None Provided")
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
                .font(.system(size: 15))
                Divider()
                HStack(alignment: .top) {
                    Image(systemName: "square.split.bottomrightquarter")
                    Text(item.lesson.roomName ?? "None Provided")
                        .lineLimit(2)
                }
                .foregroundStyle(.secondary)
                .font(.system(size: 15))
            }
            .padding(.horizontal, -7.5)
            .containerBackground(LinearGradient(colors: [item.lesson.color.opacity(0.25), item.lesson.color.opacity(0.75)], startPoint: .top, endPoint: .bottom), for: .widget)
            Text(entry.date, format: .dateTime)
                .font(.system(size: 7.5))
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.bottom, -10)
            Button(intent: RefreshWidgetsIntent()) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("REFRESH")
                }
                .font(.system(size: 7.5))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, -10)
        }
    }
}

struct TimeTableWidget: Widget {
    let kind = "TimeTableWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimeTableTimelineProvider()) { entry in
            TimeTableWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Class")
        .description("Updates every minute.")
        #if os(iOS)
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline, .systemLarge, .systemExtraLarge])
        #elseif os(macOS)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        #endif
    }
}
