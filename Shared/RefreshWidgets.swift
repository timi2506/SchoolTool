import SwiftUI
import AppIntents
#if canImport(WidgetKit)
import WidgetKit


struct RefreshWidgetsIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Widgets"
    static var description: IntentDescription = "Refreshes All Widgets"
    static var openAppWhenRun = true
    
    func perform() async throws -> some IntentResult {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result()
    }
}

struct EmptyTimeLineProvider: TimelineProvider {
    func placeholder(in context: Context) -> RefreshWidgetEntry {
        return RefreshWidgetEntry(date: .iphoneReleaseDate)
    }
    func getSnapshot(in context: Context, completion: @escaping (RefreshWidgetEntry) -> Void) {
        completion(RefreshWidgetEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<RefreshWidgetEntry>) -> Void) {
        completion(Timeline(entries: [RefreshWidgetEntry(date: .now)], policy: .never))
    }
}

struct RefreshWidgetEntry: TimelineEntry {
    var date: Date
}

struct RefreshWidget: Widget {
    let kind = "RefreshWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EmptyTimeLineProvider()) { entry in
            RefreshWidgetView(entry: entry)
        }
        .configurationDisplayName("Refresh Widgets")
        .description("Use this Widget to manually refresh Widgets.")
        #if os(watchOS)
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
        #elseif os(iOS)
        .supportedFamilies([.systemSmall,.accessoryCircular, .accessoryInline, .accessoryRectangular])
        #elseif os(macOS)
        .supportedFamilies([.systemSmall])
        #endif
    }
}

struct RefreshWidgetView: View {
    var entry: RefreshWidgetEntry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        Group {
            switch widgetFamily {
#if os(watchOS)
                case .accessoryCorner: accessoryCircularCorner()
#else
                case .systemSmall: systemSmall()
#endif
                case .accessoryCircular: accessoryCircularCorner()
                case .accessoryInline: accessoryInline()
                case .accessoryRectangular: accessoryRectangular()
                default: Button("Refresh Widgets", systemImage: "arrow.clockwise", intent: RefreshWidgetsIntent())
            }
        }
            .containerBackground(.fill.tertiary, for: .widget)
            .tint(.blue)
            .widgetAccentable()
    }
    func accessoryRectangular() -> some View {
        HStack {
            Button(intent: RefreshWidgetsIntent()) {
                Image(systemName: "arrow.clockwise")
                    .font(.headline)
            }
            .buttonBorderShape(.circle)
            Text("Refresh Widgets")
        }
    }
    func accessoryInline() -> some View {
        Button("Refresh Widgets", systemImage: "arrow.clockwise", intent: RefreshWidgetsIntent())
    }
    func accessoryCircularCorner() -> some View {
        ZStack {
            AccessoryWidgetBackground()
            Button(intent: RefreshWidgetsIntent()) {
                Image(systemName: "arrow.clockwise")
                    .font(.title)
            }
            .buttonBorderShape(.circle)
        }
        #if os(watchOS)
        .widgetLabel("Refresh Widgets")
        #endif
    }
    func systemSmall() -> some View {
        VStack(alignment: .leading) {
            Button(intent: RefreshWidgetsIntent()) {
                Image(systemName: "arrow.clockwise")
                    .font(.headline)
            }
            .buttonBorderShape(.circle)
            Text("Refresh Widgets")
                .multilineTextAlignment(.leading)
        }
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
#endif
