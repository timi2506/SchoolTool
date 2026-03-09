import SwiftUI

// MARK: - navStacked

extension View {
    func navStacked() -> some View {
        NavigationStack { self }
    }
}

// MARK: - ClassDetailView
// Shared across iOS, macOS, tvOS, and watchOS.
// On iOS/macOS it exposes an "Edit" button that opens the editor sheet.

struct ClassDetailView: View {
    var item: ScheduleClass
    var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    #if !os(watchOS)
    @Binding var showEditor: Bool
    @Environment(\.dismiss) var dismiss
    #endif

    var body: some View {
        Form {
            HStack {
                Spacer()
                ContentUnavailableView {
                    Text(item.lesson.name)
                        .font(.title)
                        .bold()
                    Image(systemName: item.lesson.symbol)
                        .symbolVariant(.none)
                        .font(.system(size: 35))
                }
                ContentUnavailableView(item.lesson.name, systemImage: item.lesson.symbol)
                Spacer()
            }
            Section("Details") {
                HStack {
                    Text("Teacher")
                    Spacer()
                    Text(item.lesson.teacherName ?? "none")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Room")
                    Spacer()
                    Text(item.lesson.roomName ?? "none")
                        .foregroundStyle(.secondary)
                }
            }
            Section("Times") {
                HStack {
                    Text("Start Time")
                    Spacer()
                    Text(item.time.startDate, formatter: timeFormatter)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("End Time")
                    Spacer()
                    Text(item.time.endDate, formatter: timeFormatter)
                        .foregroundStyle(.secondary)
                }
            }
        }
        #if !os(watchOS)
        .formStyle(.grouped)
        #endif
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: [item.lesson.color.opacity(0.25), item.lesson.color.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            ),
            ignoresSafeAreaEdges: .all
        )
        .navigationTitle("Lesson Details")
        #if !os(watchOS)
        .toolbar {
            Button("Edit") {
                withAnimation(.bouncy(duration: 0.35)) {
                    dismiss()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showEditor = true
                }
            }
        }
        #endif
    }
}

// MARK: - LessonRowLabel
// Shared label used by both the iOS/macOS LessonRow and the watchOS NavigationLink.
// Mirrors the full iOS labelView layout so both platforms look identical.

struct LessonRowLabel: View {
    var item: ScheduleClass
    #if !os(watchOS)
    @AppStorage("fullColorRow") var fullColorRow = false
    #endif

    private var hasTeacher: Bool {
        item.lesson.teacherName?.isEmpty == false
    }
    private var hasRoom: Bool {
        item.lesson.roomName?.isEmpty == false
    }

    // Single instance of the icon/name/subtitle row.
    private var singleRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: item.lesson.symbol)
                .foregroundStyle(.primary)
                .frame(width: 25)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.lesson.name)
                    .font(.body)
                HStack(spacing: 8) {
                    if !hasTeacher && !hasRoom {
                        Text("No Additional Information")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        if let teacher = item.lesson.teacherName, !teacher.isEmpty {
                            Text(teacher)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let room = item.lesson.roomName, !room.isEmpty {
                            if hasTeacher {
                                Divider()
                            }
                            Text("Room \(room)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer()
            #if !os(watchOS)
            if !fullColorRow {
                Circle()
                    .fill(item.lesson.color)
                    .frame(width: 10, height: 10)
            }
            #endif
        }
        .padding(.vertical, 10)
    }

    var body: some View {
        VStack(spacing: 0) {
            singleRow
            if item.forceDoubleLesson == true {
                Spacer().frame(height: 5)
                Divider()
                Spacer().frame(height: 5)
                singleRow
            }
        }
    }
}

// MARK: - iOS / macOS / tvOS-only views

#if !os(watchOS)

// MARK: LessonRow

struct LessonRow: View {
    var item: ScheduleClass
    var onDelete: (() -> Void)? = nil
    @State private var showEditor = false

    var body: some View {
        NavigationLink {
            ClassDetailView(item: item, showEditor: $showEditor)
        } label: {
            LessonRowLabel(item: item)
                .contentShape(.rect)
                .contextMenu {
                    #if canImport(SymbolPicker)
                    Button {
                        showEditor = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    #endif
                    Button(role: .destructive) {
                        onDelete?()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                #if canImport(SymbolPicker)
                .sheet(isPresented: $showEditor) {
                    LessonEditorView(original: item)
                }
                #endif
        }
        .buttonStyle(.plain)
    }
}

// MARK: TimeTableView

struct TimeTableView: View {
    @StateObject var timeTableManager = TimeTableManager.shared
    @State var addSchedule = false
    @State var selectedDay: TimeTableSchedule.Days = .today

    var body: some View {
        VStack {
            if let schedule = timeTableManager.schedule {
                if let scheduleDay = schedule.days.first(where: { $0.day == selectedDay }) {
                    let yesterday = previousDayWithItems(before: selectedDay, in: schedule)
                    let tomorrow = nextDayWithItems(after: selectedDay, in: schedule)

                    DayColumnView(day: scheduleDay, selectedDay: $selectedDay, addSchedule: $addSchedule)
                        .dragAction { side in
                            switch side {
                            case .left:  selectedDay = yesterday
                            case .right: selectedDay = tomorrow
                            }
                        }
                        .id(scheduleDay)
                }
            } else {
                ContentUnavailableView("Time Table not configured", systemImage: "calendar")
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
            EditButton()
            #endif
            #if canImport(SymbolPicker)
            Button("Add", systemImage: "plus") {
                addSchedule.toggle()
            }
            .labelStyle(.iconOnly)
            #endif
        }
        #if canImport(SymbolPicker)
        .sheet(isPresented: $addSchedule) {
            AddScheduleView(selectedTime: .init(
                day: selectedDay,
                start: .init(from: Date()),
                end: .init(from: Date().addingTimeInterval(3600))
            ))
        }
        #endif
        .navStacked()
    }

    private func nextDayWithItems(after currentDay: TimeTableSchedule.Days, in schedule: TimeTableSchedule) -> TimeTableSchedule.Days {
        var checkDay = currentDay.tomorrow
        while checkDay != currentDay {
            if let daySchedule = schedule.days.first(where: { $0.day == checkDay }), !daySchedule.classes.isEmpty {
                return checkDay
            }
            checkDay = checkDay.tomorrow
        }
        return currentDay
    }

    private func previousDayWithItems(before currentDay: TimeTableSchedule.Days, in schedule: TimeTableSchedule) -> TimeTableSchedule.Days {
        var checkDay = currentDay.yesterday
        while checkDay != currentDay {
            if let daySchedule = schedule.days.first(where: { $0.day == checkDay }), !daySchedule.classes.isEmpty {
                return checkDay
            }
            checkDay = checkDay.yesterday
        }
        return currentDay
    }
}

// MARK: DayColumnView

struct DayColumnView: View {
    @StateObject private var manager = TimeTableManager.shared
    @AppStorage("fullColorRow") var fullColorRow = false
    #if !os(macOS)
    @Environment(\.editMode) var editMode
    #endif
    var day: TimeTableSchedule.TimeTableDay
    @Binding var selectedDay: TimeTableSchedule.Days
    @Binding var addSchedule: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if day.classes.isEmpty {
                ContentUnavailableView {
                    Label("No Classes for this Day", systemImage: "text.badge.plus")
                } description: {
                    Text("Try adding some")
                } actions: {
                    Button("Add", systemImage: "plus") {
                        addSchedule.toggle()
                    }
                    .borderedProminent()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Form {
                    ForEach(day.classes) { item in
                        Section(timeRangeString(item)) {
                            LessonRow(item: item) {
                                delete(item)
                            }
                            #if os(iOS) || os(macOS)
                            .listRowBackground(
                                fullColorRow
                                    ? LinearGradient(colors: [item.lesson.color.opacity(0.25), item.lesson.color.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom)
                            )
                            #endif
                        }
                    }
                    .onDelete { indexSet in
                        delete(at: indexSet)
                    }
                    #if !os(macOS)
                    .deleteDisabled(editMode?.wrappedValue != EditMode.active)
                    #endif
                }
                .formStyle(.grouped)
                #if os(macOS) || os(iOS)
                .scrollContentBackground(.hidden)
                #endif
            }
        }
        .background {
            #if os(iOS) || os(macOS)
            LinearGradient(colors: [.clear, .gray.opacity(0.35)], startPoint: .bottom, endPoint: .top)
                .ignoresSafeArea(.all)
            #endif
        }
        .navigationTitle(day.day.name)
        .toolbarTitleMenu {
            let today = TimeTableSchedule.Days.today
            Section("Today") {
                Button(today.name, systemImage: selectedDay == today ? "checkmark" : today.icon) {
                    selectedDay = today
                }
            }
            ForEach(TimeTableSchedule.Days.allCases.filter { $0 != .today }, id: \.self) { day in
                Button(day.name, systemImage: selectedDay == day ? "checkmark" : day.icon) {
                    selectedDay = day
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        guard var schedule = manager.schedule,
              let dayIndex = schedule.days.firstIndex(where: { $0.day == day.day }) else { return }
        schedule.days[dayIndex].classes.remove(atOffsets: offsets)
        manager.schedule = schedule
    }

    private func delete(_ item: ScheduleClass) {
        guard var schedule = manager.schedule,
              let dayIndex = schedule.days.firstIndex(where: { $0.day == day.day }),
              let classIndex = schedule.days[dayIndex].classes.firstIndex(of: item) else { return }
        schedule.days[dayIndex].classes.remove(at: classIndex)
        manager.schedule = schedule
    }

    private func timeRangeString(_ item: ScheduleClass) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(formatter.string(from: item.time.startDate)) – \(formatter.string(from: item.time.endDate))"
    }
}

// MARK: - DragActionModifier (iOS / macOS only)

#if os(iOS) || os(macOS)

#if os(macOS)
import AppKit
#endif

extension View {
    func dragAction(_ action: @escaping (DragActionModifier.Side) -> Void) -> some View {
        modifier(DragActionModifier(action: action))
    }
}

struct DragActionModifier: ViewModifier {
    enum DragDirection { case undecided, horizontal, vertical }
    enum Side { case left, right }

    @State private var xOffset: CGFloat = 0
    @State private var direction: DragDirection = .undecided
    @State private var playedHaptic = false
    @State private var disableAllOtherGestures = false
    @State private var dragSide: Side?

    let action: (Side) -> Void

    func body(content: Content) -> some View {
        content
            .transition(.scale.combined(with: .push(from: dragSide == .left ? .leading : dragSide == .right ? .trailing : .bottom)).combined(with: .opacity))
            .blur(radius: disableAllOtherGestures ? 10 : 0)
            .offset(x: xOffset * 0.05)
            .contentShape(.rect)
            .disabled(disableAllOtherGestures)
            .scrollDisabled(disableAllOtherGestures)
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        let dx = value.translation.width
                        let dy = value.translation.height
                        if direction == .undecided {
                            if abs(dx) > 10 || abs(dy) > 10 {
                                direction = abs(dx) > abs(dy) ? .horizontal : .vertical
                            }
                        }
                        guard direction == .horizontal else { return }
                        if !disableAllOtherGestures {
                            withAnimation { disableAllOtherGestures = true }
                        }
                        withAnimation {
                            if xOffset >= 200 && !playedHaptic {
                                playHaptic(); playedHaptic = true
                            } else if xOffset <= -200 && !playedHaptic {
                                playHaptic(); playedHaptic = true
                            } else if xOffset < 195 && xOffset > 0 && playedHaptic {
                                playedHaptic = false
                            } else if xOffset > -195 && xOffset < 0 && playedHaptic {
                                playedHaptic = false
                            }
                        }
                        withAnimation {
                            if abs(dx) > 50 {
                                if xOffset == 0 {
                                    xOffset = dx
                                } else if (xOffset > 0 && dx > 0) || (xOffset < 0 && dx < 0) {
                                    xOffset = dx
                                }
                            }
                        }
                        let newSide: Side = xOffset < 0 ? .right : .left
                        if dragSide != newSide { dragSide = newSide }
                    }
                    .onEnded { _ in
                        if direction == .horizontal {
                            if xOffset >= 200 { action(.left) }
                            if xOffset <= -200 { action(.right) }
                        }
                        withAnimation(.smooth) {
                            xOffset = 0
                            disableAllOtherGestures = false
                        }
                        playedHaptic = false
                        direction = .undecided
                    }
            )
            .overlay(alignment: .leading) {
                Image(systemName: "chevron.left")
                    .padding()
                    .background {
                        Circle()
                            .foregroundStyle(.ultraThickMaterial)
                            .blur(radius: playedHaptic ? 0 : 10)
                            .overlay {
                                Circle().stroke(.gray.opacity(playedHaptic ? 0.25 : 0))
                            }
                    }
                    .offset(x: (xOffset * 0.5) - 75)
                    .opacity(xOffset == 0 ? 0 : 1)
            }
            .overlay(alignment: .trailing) {
                Image(systemName: "chevron.right")
                    .padding()
                    .background {
                        Circle()
                            .foregroundStyle(.ultraThickMaterial)
                            .blur(radius: playedHaptic ? 0 : 10)
                    }
                    .offset(x: (xOffset * 0.5) + 75)
                    .opacity(xOffset == 0 ? 0 : 1)
            }
    }

    private func playHaptic() {
        #if os(iOS)
        let gen = UIImpactFeedbackGenerator(style: .heavy)
        gen.impactOccurred()
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        #endif
    }
}

#endif // os(iOS) || os(macOS) — DragActionModifier

// MARK: - Add / Edit Views (require SymbolPicker)

#if canImport(SymbolPicker)
import SymbolPicker

struct AddScheduleView: View {
    @Environment(\.dismiss) var dismiss
    @State var selectedTime = TimeTableTime(day: .monday, start: .init(from: Date()), end: .init(from: Date().addingTimeInterval(3600)))
    @State var lesson: TimeTableLesson = .init(name: "", teacherName: nil, roomName: nil, color: .blue)
    @FocusState var nameFocused: Bool
    @FocusState var teacherFocused: Bool
    @State var forceDoubleLesson = false
    var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        VStack {
            HStack {
                Button("Cancel") { dismiss() }
                    .bordered()
                    .buttonBorderShape(.capsule)
                Spacer()
                Text("Add Lesson").bold()
                Spacer()
                Button("Done") { addLesson() }
                    .borderedProminent()
                    .buttonBorderShape(.capsule)
                    .disabled(lesson.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isTimeValid)
            }
            .padding()

            Form {
                lessonNameSection
                scheduleTimeSection
                detailsSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .background(
            LinearGradient(colors: [lesson.color.opacity(0.25), lesson.color.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                .id(lesson.color)
                .contentTransition(.opacity)
        )
        .animation(.default, value: nameFocused)
        .animation(.default, value: lesson)
        .navStacked()
    }

    @ViewBuilder
    private var lessonNameSection: some View {
        Section("Lesson Name") {
            HStack {
                TextField("(e.g. Maths)", text: $lesson.name)
                    .focused($nameFocused)
                    .textFieldStyle(.plain)
                Spacer()
                Circle()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(lesson.name.isEmpty ? .red : .green)
            }
            if nameFocused {
                if !lesson.name.isEmpty {
                    if lessonSuggestions.isEmpty {
                        Text("No Suggestions").foregroundStyle(.secondary)
                    }
                    ForEach(lessonSuggestions) { suggestion in
                        suggestionView(for: suggestion, lesson: $lesson)
                    }
                } else {
                    Text("Start typing to see Suggestions...").foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var scheduleTimeSection: some View {
        Section("Schedule Time") {
            Picker("Day", selection: $selectedTime.day) {
                ForEach(TimeTableSchedule.Days.allCases, id: \.self) { day in
                    Text(day.name).tag(day)
                }
            }
            VStack(alignment: .leading) {
                DatePicker("Start Time", selection: $selectedTime.startDate, displayedComponents: .hourAndMinute)
                timeRecommendationMenu(times: startTimeRecommendations) { selectedTime.startDate = $0 }
            }
            VStack(alignment: .leading) {
                DatePicker("End Time", selection: $selectedTime.endDate, displayedComponents: .hourAndMinute)
                timeRecommendationMenu(times: endTimeRecommendations) { selectedTime.endDate = $0 }
            }
            if !isTimeValid {
                Label("End time must be after start time", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange).font(.footnote)
            }
            VStack(alignment: .leading) {
                Toggle("Double Lesson", isOn: $forceDoubleLesson)
                Text("Makes SchoolTool treat this Class as a Double Lesson")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
            }
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        Section("Details (Optional)") {
            TextField("Teacher", text: Binding(
                get: { lesson.teacherName ?? "" },
                set: { lesson.teacherName = $0.isEmpty ? nil : $0 }
            ))
            .focused($teacherFocused)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    if teacherFocused {
                        ScrollView(.horizontal) {
                            HStack {
                                if teacherSuggestions.isEmpty {
                                    Text("Suggestions will appear as you type")
                                        .foregroundStyle(.secondary).padding(.horizontal)
                                }
                                ForEach(teacherSuggestions, id: \.self) { teacher in
                                    Button(teacher) { lesson.teacherName = teacher }
                                    if teacher != teacherSuggestions.last { Divider() }
                                }
                            }
                        }
                    }
                }
            }
            TextField("Room", text: Binding(
                get: { lesson.roomName ?? "" },
                set: { lesson.roomName = $0.isEmpty ? nil : $0 }
            ))
            #if os(iOS)
            CustomColorPicker(color: $lesson.color)
            #elseif os(macOS)
            ColorPicker("Accent Color", selection: $lesson.color)
            #endif
            NavigationLink(destination: {
                SymbolPicker(symbol: $lesson.symbol)
                    .navigationTitle("Pick a Symbol")
            }) {
                HStack {
                    Text("Symbol")
                    Spacer()
                    Image(systemName: lesson.symbol)
                }
            }
        }
    }

    func suggestionView(for suggestion: TimeTableLesson, lesson: Binding<TimeTableLesson>) -> some View {
        Button(action: {
            withAnimation {
                lesson.wrappedValue.name = suggestion.name
                lesson.wrappedValue.color = suggestion.color
                if let teacherName = suggestion.teacherName { lesson.wrappedValue.teacherName = teacherName }
                if let roomName = suggestion.roomName { lesson.wrappedValue.roomName = roomName }
                lesson.wrappedValue.symbol = suggestion.symbol
                nameFocused = false
            }
        }) {
            HStack(alignment: .center) {
                Image(systemName: suggestion.symbol).foregroundStyle(.primary).frame(width: 25)
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.name).font(.headline).foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        if let teacher = suggestion.teacherName, !teacher.isEmpty {
                            Text(teacher).font(.subheadline).foregroundStyle(.secondary)
                        }
                        if let room = suggestion.roomName, !room.isEmpty {
                            if suggestion.teacherName != nil { Divider() }
                            Text("Room \(room)").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                if lesson.wrappedValue == suggestion {
                    Image(systemName: "checkmark")
                } else {
                    Circle().fill(suggestion.color).frame(width: 10, height: 10)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func timeRecommendationMenu(times: [Date], onSelect: @escaping (Date) -> Void) -> some View {
        Menu {
            ForEach(times, id: \.self) { time in
                Button(action: { onSelect(time) }) {
                    Text(time, formatter: timeFormatter)
                }
            }
        } label: {
            HStack {
                Text("Recommendations")
                Spacer()
                Text(times.count, format: .number)
                Image(systemName: "chevron.down")
            }
            .font(.caption).foregroundStyle(.secondary).contentShape(.rect)
        }
        .disabled(times.isEmpty)
        .menuStyle(.button)
        .buttonStyle(.plain)
    }

    private var startTimeRecommendations: [Date] {
        uniqueSortedTimes(keyPath: \.time.start)
    }
    private var endTimeRecommendations: [Date] {
        uniqueSortedTimes(keyPath: \.time.end)
    }

    private func uniqueSortedTimes(keyPath: KeyPath<ScheduleClass, TimeOfDay>) -> [Date] {
        var added: [Date] = []
        let all = TimeTableManager.shared.schedule?.days.flatMap { $0.classes.compactMap { cls -> Date? in
            let candidate = cls[keyPath: keyPath].asToday
            if !added.contains(candidate) { added.append(candidate); return candidate }
            return nil
        } } ?? []
        return all.sorted { lhs, rhs in
            let cal = Calendar.current
            let l = cal.dateComponents([.hour, .minute, .second], from: lhs)
            let r = cal.dateComponents([.hour, .minute, .second], from: rhs)
            if l.hour != r.hour { return (l.hour ?? 0) < (r.hour ?? 0) }
            if l.minute != r.minute { return (l.minute ?? 0) < (r.minute ?? 0) }
            return (l.second ?? 0) < (r.second ?? 0)
        }
    }

    private var lessonSuggestions: [TimeTableLesson] {
        var added: [TimeTableLesson] = []
        let all = TimeTableManager.shared.schedule?.days.flatMap({ $0.classes.compactMap({ classItem in
            if !added.contains(where: { $0.name == classItem.lesson.name && $0.color == classItem.lesson.color && $0.teacherName == classItem.lesson.teacherName && $0.roomName == classItem.lesson.roomName }) {
                added.append(classItem.lesson); return classItem.lesson
            }
            return nil
        }) })
        return all?.filter({ $0.name.lowercased().contains(lesson.name.lowercased()) }) ?? []
    }

    var teacherSuggestions: [String] {
        guard let current = lesson.teacherName else { return [] }
        var added: [String] = []
        let all = TimeTableManager.shared.schedule?.days.flatMap({ $0.classes.compactMap({
            if let teacherName = $0.lesson.teacherName, !added.contains(teacherName) { added.append(teacherName); return teacherName }
            return nil
        }) })
        return all?.filter({ $0.lowercased().contains(current.lowercased()) }) ?? []
    }

    var isTimeValid: Bool {
        selectedTime.end.hour * 60 + selectedTime.end.minute > selectedTime.start.hour * 60 + selectedTime.start.minute
    }

    private func addLesson() {
        guard isTimeValid else { return }
        lesson.name = lesson.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let manager = TimeTableManager.shared
        var schedule = manager.schedule ?? TimeTableSchedule(id: UUID(), days: TimeTableSchedule.Days.allCases.map { TimeTableSchedule.TimeTableDay(day: $0, classes: []) })
        let newClass = ScheduleClass(time: selectedTime, lesson: lesson, forceDoubleLesson: forceDoubleLesson)
        if let idx = schedule.days.firstIndex(where: { $0.day == selectedTime.day }) {
            schedule.days[idx].classes.append(newClass)
            schedule.days[idx].classes.sort { $0.time.start.hour * 60 + $0.time.start.minute < $1.time.start.hour * 60 + $1.time.start.minute }
        }
        manager.schedule = schedule
        dismiss()
    }
}

struct LessonEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTime: TimeTableTime
    @State private var lesson: TimeTableLesson
    @FocusState private var nameFocused: Bool
    @FocusState private var teacherFocused: Bool
    @State var forceDoubleLesson = false
    private let original: ScheduleClass

    init(original: ScheduleClass) {
        self._selectedTime = State(initialValue: original.time)
        self._lesson = State(initialValue: original.lesson)
        self._forceDoubleLesson = State(initialValue: original.forceDoubleLesson ?? false)
        self.original = original
    }
    var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        VStack {
            HStack {
                Button("Cancel") { dismiss() }
                    .bordered()
                    .buttonBorderShape(.capsule)
                Spacer()
                Text("Edit Lesson").bold()
                Spacer()
                Button("Done") { saveEdits() }
                    .borderedProminent()
                    .buttonBorderShape(.capsule)
                    .disabled(lesson.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isTimeValid)
            }
            .padding()

            Form {
                lessonNameSection
                scheduleTimeSection
                detailsSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .background(
            LinearGradient(colors: [lesson.color.opacity(0.25), lesson.color.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                .id(lesson.color).contentTransition(.opacity)
        )
        .animation(.default, value: nameFocused)
        .animation(.default, value: lesson)
        .navStacked()
    }

    @ViewBuilder
    private var lessonNameSection: some View {
        Section("Lesson Name") {
            HStack {
                TextField("(e.g. Maths)", text: $lesson.name)
                    .focused($nameFocused).textFieldStyle(.plain)
                Spacer()
                Circle().frame(width: 10, height: 10)
                    .foregroundStyle(lesson.name.isEmpty ? .red : .green)
            }
            if nameFocused {
                if !lesson.name.isEmpty {
                    if lessonSuggestions.isEmpty {
                        Text("No Suggestions").foregroundStyle(.secondary)
                    }
                    ForEach(lessonSuggestions) { suggestion in
                        suggestionView(for: suggestion, lesson: $lesson)
                    }
                } else {
                    Text("Start typing to see Suggestions...").foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var scheduleTimeSection: some View {
        Section("Schedule Time") {
            Picker("Day", selection: $selectedTime.day) {
                ForEach(TimeTableSchedule.Days.allCases, id: \.self) { day in
                    Text(day.name).tag(day)
                }
            }
            VStack(alignment: .leading) {
                DatePicker("Start Time", selection: $selectedTime.startDate, displayedComponents: .hourAndMinute)
                timeRecommendationMenu(times: startTimeRecommendations) { selectedTime.startDate = $0 }
            }
            VStack(alignment: .leading) {
                DatePicker("End Time", selection: $selectedTime.endDate, displayedComponents: .hourAndMinute)
                timeRecommendationMenu(times: endTimeRecommendations) { selectedTime.endDate = $0 }
            }
            if !isTimeValid {
                Label("End time must be after start time", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange).font(.footnote)
            }
            VStack(alignment: .leading) {
                Toggle("Double Lesson", isOn: $forceDoubleLesson)
                Text("Makes SchoolTool treat this Class as a Double Lesson")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
            }
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        Section("Details (Optional)") {
            TextField("Teacher", text: Binding(
                get: { lesson.teacherName ?? "" },
                set: { lesson.teacherName = $0.isEmpty ? nil : $0 }
            ))
            .focused($teacherFocused)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    if teacherFocused {
                        ScrollView(.horizontal) {
                            HStack {
                                if teacherSuggestions.isEmpty {
                                    Text("Suggestions will appear as you type")
                                        .foregroundStyle(.secondary).padding(.horizontal)
                                }
                                ForEach(teacherSuggestions, id: \.self) { teacher in
                                    Button(teacher) { lesson.teacherName = teacher }
                                    if teacher != teacherSuggestions.last { Divider() }
                                }
                            }
                        }
                    }
                }
            }
            TextField("Room", text: Binding(
                get: { lesson.roomName ?? "" },
                set: { lesson.roomName = $0.isEmpty ? nil : $0 }
            ))
            #if os(iOS)
            CustomColorPicker(color: $lesson.color)
            #elseif os(macOS)
            ColorPicker("Accent Color", selection: $lesson.color)
            #endif
            NavigationLink(destination: {
                SymbolPicker(symbol: $lesson.symbol)
                    .navigationTitle("Pick a Symbol")
            }) {
                HStack {
                    Text("Symbol")
                    Spacer()
                    Image(systemName: lesson.symbol)
                }
            }
        }
    }

    func suggestionView(for suggestion: TimeTableLesson, lesson: Binding<TimeTableLesson>) -> some View {
        Button(action: {
            withAnimation {
                lesson.wrappedValue.name = suggestion.name
                lesson.wrappedValue.color = suggestion.color
                if let teacherName = suggestion.teacherName { lesson.wrappedValue.teacherName = teacherName }
                if let roomName = suggestion.roomName { lesson.wrappedValue.roomName = roomName }
                lesson.wrappedValue.symbol = suggestion.symbol
                nameFocused = false
            }
        }) {
            HStack(alignment: .center) {
                Image(systemName: suggestion.symbol).foregroundStyle(.primary).frame(width: 25)
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.name).font(.headline).foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        if let teacher = suggestion.teacherName, !teacher.isEmpty {
                            Text(teacher).font(.subheadline).foregroundStyle(.secondary)
                        }
                        if let room = suggestion.roomName, !room.isEmpty {
                            if suggestion.teacherName != nil { Divider() }
                            Text("Room \(room)").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                if lesson.wrappedValue == suggestion {
                    Image(systemName: "checkmark")
                } else {
                    Circle().fill(suggestion.color).frame(width: 10, height: 10)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func timeRecommendationMenu(times: [Date], onSelect: @escaping (Date) -> Void) -> some View {
        Menu {
            ForEach(times, id: \.self) { time in
                Button(action: { onSelect(time) }) {
                    Text(time, formatter: timeFormatter)
                }
            }
        } label: {
            HStack {
                Text("Recommendations")
                Spacer()
                Text(times.count, format: .number)
                Image(systemName: "chevron.down")
            }
            .font(.caption).foregroundStyle(.secondary).contentShape(.rect)
        }
        .disabled(times.isEmpty)
        .menuStyle(.button)
        .buttonStyle(.plain)
    }

    private var startTimeRecommendations: [Date] { uniqueSortedTimes(keyPath: \.time.start) }
    private var endTimeRecommendations: [Date]   { uniqueSortedTimes(keyPath: \.time.end) }

    private func uniqueSortedTimes(keyPath: KeyPath<ScheduleClass, TimeOfDay>) -> [Date] {
        var added: [Date] = []
        let all = TimeTableManager.shared.schedule?.days.flatMap { $0.classes.compactMap { cls -> Date? in
            let candidate = cls[keyPath: keyPath].asToday
            if !added.contains(candidate) { added.append(candidate); return candidate }
            return nil
        } } ?? []
        return all.sorted { lhs, rhs in
            let cal = Calendar.current
            let l = cal.dateComponents([.hour, .minute, .second], from: lhs)
            let r = cal.dateComponents([.hour, .minute, .second], from: rhs)
            if l.hour != r.hour { return (l.hour ?? 0) < (r.hour ?? 0) }
            if l.minute != r.minute { return (l.minute ?? 0) < (r.minute ?? 0) }
            return (l.second ?? 0) < (r.second ?? 0)
        }
    }

    private var lessonSuggestions: [TimeTableLesson] {
        var added: [TimeTableLesson] = []
        let all = TimeTableManager.shared.schedule?.days.flatMap({ $0.classes.compactMap({ classItem in
            if !added.contains(where: { $0.name == classItem.lesson.name && $0.color == classItem.lesson.color && $0.teacherName == classItem.lesson.teacherName && $0.roomName == classItem.lesson.roomName }) {
                added.append(classItem.lesson); return classItem.lesson
            }
            return nil
        }) })
        return all?.filter({ $0.name.lowercased().contains(lesson.name.lowercased()) }) ?? []
    }

    private var teacherSuggestions: [String] {
        guard let current = lesson.teacherName else { return [] }
        var added: [String] = []
        let all = TimeTableManager.shared.schedule?.days.flatMap({ $0.classes.compactMap({
            if let teacherName = $0.lesson.teacherName, !added.contains(teacherName) { added.append(teacherName); return teacherName }
            return nil
        }) })
        return all?.filter({ $0.lowercased().contains(current.lowercased()) }) ?? []
    }

    private var isTimeValid: Bool {
        selectedTime.end.hour * 60 + selectedTime.end.minute > selectedTime.start.hour * 60 + selectedTime.start.minute
    }

    private func saveEdits() {
        guard isTimeValid else { return }
        let trimmedName = lesson.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        lesson.name = trimmedName
        let manager = TimeTableManager.shared
        guard var schedule = manager.schedule else { return }
        guard let origDayIdx = schedule.days.firstIndex(where: { $0.day == original.time.day }),
              let origClassIdx = schedule.days[origDayIdx].classes.firstIndex(where: { $0.id == original.id }) else { return }
        let updated = ScheduleClass(id: original.id, time: selectedTime, lesson: lesson, forceDoubleLesson: forceDoubleLesson)
        if selectedTime.day == original.time.day {
            schedule.days[origDayIdx].classes[origClassIdx] = updated
            schedule.days[origDayIdx].classes.sort { $0.time.start.hour * 60 + $0.time.start.minute < $1.time.start.hour * 60 + $1.time.start.minute }
        } else {
            schedule.days[origDayIdx].classes.remove(at: origClassIdx)
            if let newDayIdx = schedule.days.firstIndex(where: { $0.day == selectedTime.day }) {
                schedule.days[newDayIdx].classes.append(updated)
                schedule.days[newDayIdx].classes.sort { $0.time.start.hour * 60 + $0.time.start.minute < $1.time.start.hour * 60 + $1.time.start.minute }
            }
        }
        manager.schedule = schedule
        dismiss()
    }
}

#endif // canImport(SymbolPicker)

#endif // !os(watchOS)

extension View {
    @ViewBuilder func bordered() -> some View {
        if #available(iOS 26, watchOS 26, macOS 26, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }
    @ViewBuilder func borderedProminent() -> some View {
        if #available(iOS 26, watchOS 26, macOS 26, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
}
