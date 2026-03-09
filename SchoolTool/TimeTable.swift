import SwiftUI
import Combine

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
                            case .left:
                                selectedDay = yesterday
                            case .right:
                                selectedDay = tomorrow
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
#if os(macOS) || os(iOS)
            Button("Add", systemImage: "plus") {
                addSchedule.toggle()
            }
            .labelStyle(.iconOnly)
            #endif
        }
#if os(macOS) || os(iOS)
        .sheet(isPresented: $addSchedule) {
            AddScheduleView(selectedTime: .init(day: selectedDay, start: .init(from: Date()), end: .init(from: Date().addingTimeInterval(3600))))
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
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Form {
                    ForEach(day.classes) { item in
                        Section(timeRangeString(item)) {
                            LessonRow(item: item) {
                                delete(item)
                            }
#if os(iOS)
                            .listRowBackground(fullColorRow ? LinearGradient(colors: [item.lesson.color.opacity( 0.25), item.lesson.color.opacity(0.75)], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom))
#endif
                        }
                    }
                    .onDelete { indexSet in
                        delete(at: indexSet)
                    }
                    .deleteDisabled(editMode?.wrappedValue != EditMode.active)
                }
                .formStyle(.grouped)
#if os(macOS) || os(iOS)
                .scrollContentBackground(.hidden)
#endif
            }
        }
        .background {
#if os(iOS)
            LinearGradient(colors: [.clear, .gray.opacity(0.35)], startPoint: .bottom, endPoint: .top)
                .ignoresSafeArea(.all)
#elseif os(macOS)
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
            ForEach(TimeTableSchedule.Days.allCases
                .filter {
                    $0 != .today
                }, id: \.self) { day in
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

struct ClassDetailView: View {
    var item: ScheduleClass
    var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = .none
        formatter.timeStyle = .short
        return formatter
    }
    @Binding var showEditor: Bool
    @Environment(\.dismiss) var dismiss
    var body: some View {
        Form {
            HStack {
                Spacer()
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
        .formStyle(.grouped)
#if os(macOS) || os(iOS)
        .scrollContentBackground(.hidden)
#endif
        .background(LinearGradient(colors: [item.lesson.color.opacity(0.25), item.lesson.color.opacity(0.75)], startPoint: .top, endPoint: .bottom))
        .navigationTitle("Lesson Details")
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
    }
}

struct LessonRow: View {
    @AppStorage("fullColorRow") var fullColorRow = false

    var item: ScheduleClass
    var onDelete: (() -> Void)? = nil
    @State private var showEditor = false

    var primary: some ShapeStyle {
        #if os(iOS) || os(tvOS)
        .primary
        #elseif os(macOS)
        fullColorRow ? item.lesson.color : .primary
        #endif
    }
    var secondary: some ShapeStyle { primary.secondary }
    var body: some View {
        NavigationLink {
            ClassDetailView(item: item, showEditor: $showEditor)
        } label: {
            VStack(spacing: 0) {
                labelView
                    .padding(.vertical, 10)
                if item.forceDoubleLesson == true {
                    Spacer()
                        .frame(height: 5)
                    Divider()
                    Spacer()
                        .frame(height: 5)
                    labelView
                        .padding(.vertical, 10)
                }
            }
            .contentShape(.rect)
            .contextMenu {
#if os(iOS) || os(macOS)
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
#if os(iOS) || os(macOS)
            .sheet(isPresented: $showEditor) {
                LessonEditorView(original: item)
            }
#endif
        }
        .buttonStyle(.plain)
    }
    
    var labelView: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: item.lesson.symbol)
                .foregroundStyle(primary)
                .frame(width: 25)
            VStack(alignment: .leading, spacing: 5) {
                Text(item.lesson.name)
                    .font(.headline)
                    .foregroundStyle(primary)
                HStack(spacing: 8) {
                    if (item.lesson.teacherName == nil || item.lesson.teacherName?.isEmpty == true) && (item.lesson.roomName == nil || item.lesson.roomName?.isEmpty == true) {
                        Text("No Additional Information")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        if let teacher = item.lesson.teacherName, !teacher.isEmpty {
                            Text(teacher)
                                .font(.subheadline)
                                .foregroundStyle(secondary)
                        }
                        if let room = item.lesson.roomName, !room.isEmpty {
                            if  !((item.lesson.teacherName == nil || item.lesson.teacherName?.isEmpty == true)) {
                                Divider()
                            }
                            Text("Room \(room)")
                                .font(.subheadline)
                                .foregroundStyle(secondary)
                        }
                    }
                }
            }
            Spacer()
            if !fullColorRow {
                Circle()
                    .fill(item.lesson.color)
                    .frame(width: 10, height: 10)
            }
        }
    }
}

#if os(macOS) || os(iOS)
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
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)

                Spacer()
                Text("Add Lesson")
                    .bold()
                Spacer()
                Button("Done") {
                    addLesson()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(lesson.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isTimeValid)
            }
            .padding()

            Form {
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
                                Text("No Suggestions")
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(lessonSuggestions) { suggestion in
                                suggestionView(for: suggestion, lesson: $lesson)
                            }
                        } else {
                            Text("Start typing to see Suggestions...")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Schedule Time") {
                    Picker("Day", selection: $selectedTime.day) {
                        ForEach(TimeTableSchedule.Days.allCases, id: \.self) { day in
                            Text(day.name)
                                .tag(day)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        DatePicker("Start Time", selection: $selectedTime.startDate,  displayedComponents: .hourAndMinute)
                        Menu {
                            ForEach(startTimeRecommendations, id: \.self) { time in
                                Button(action: {
                                    selectedTime.startDate = time
                                }) {
                                    Text(time, formatter: timeFormatter)
                                }
                            }
                        } label: {
                            HStack {
                                Text("Recommendations")
                                Spacer()
                                Text(startTimeRecommendations.count, format: .number)
                                Image(systemName: "chevron.down")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .contentShape(.rect)
                        }
                        .disabled(startTimeRecommendations.isEmpty)
                        .menuStyle(.button)
                        .buttonStyle(.plain)
                    }
                    
                    VStack(alignment: .leading) {
                        DatePicker("End Time", selection: $selectedTime.endDate, displayedComponents: .hourAndMinute)
                        Menu {
                            ForEach(endTimeRecommendations, id: \.self) { time in
                                Button(action: {
                                    selectedTime.endDate = time
                                }) {
                                    Text(time, formatter: timeFormatter)
                                }
                            }
                        } label: {
                            HStack {
                                Text("Recommendations")
                                Spacer()
                                Text(endTimeRecommendations.count, format: .number)
                                Image(systemName: "chevron.down")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .contentShape(.rect)
                        }
                        .disabled(endTimeRecommendations.isEmpty)
                        .menuStyle(.button)
                        .buttonStyle(.plain)
                    }
                    
                    if !isTimeValid {
                        Label("End time must be after start time", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.footnote)
                    }
                    
                    VStack(alignment: .leading) {
                        Toggle("Double Lesson", isOn: $forceDoubleLesson)
                        Text("Makes SchoolTool to treat this Class as Double Lesson")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
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
                                                .foregroundStyle(.secondary)
                                                .padding(.horizontal)
                                        }
                                        ForEach(teacherSuggestions, id: \.self) { teacher in
                                            Button(teacher) { lesson.teacherName = teacher }
                                            if teacher != teacherSuggestions.last {
                                                Divider()
                                            }
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
    func suggestionView(for suggestion: TimeTableLesson, lesson: Binding<TimeTableLesson>) -> some View {
        Button(action: {
            withAnimation() {
                lesson.wrappedValue.name = suggestion.name
                lesson.wrappedValue.color = suggestion.color
                if let suggestedTeacherName = suggestion.teacherName {
                    lesson.wrappedValue.teacherName = suggestedTeacherName
                }
                if let roomName = suggestion.roomName {
                    lesson.wrappedValue.roomName = roomName
                }
                lesson.wrappedValue.symbol = suggestion.symbol
                nameFocused = false
            }
        }) {
            HStack(alignment: .center) {
                Image(systemName: suggestion.symbol)
                    .foregroundStyle(.primary)
                    .frame(width: 25)
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        if let teacher = suggestion.teacherName, !teacher.isEmpty {
                            Text(teacher)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let room = suggestion.roomName, !room.isEmpty {
                            if suggestion.teacherName != nil {
                                Divider()
                            }
                            Text("Room \(room)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                if lesson.wrappedValue == suggestion {
                    Image(systemName: "checkmark")
                } else {
                    Circle()
                        .fill(suggestion.color)
                        .frame(width: 10, height: 10)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
    
    private var startTimeRecommendations: [Date] {
        var added: [Date] = []
        let allSuggestions = TimeTableManager.shared.schedule?.days.flatMap { day in
            day.classes.compactMap {
                let candidate = $0.time.start.asToday
                if !added.contains(candidate) {
                    added.append(candidate)
                    return candidate
                } else {
                    return nil
                }
            }
        }
        
        return (allSuggestions ?? []).sorted { lhs, rhs in
            let calendar = Calendar.current
            let lhsComponents = calendar.dateComponents([.hour, .minute, .second], from: lhs)
            let rhsComponents = calendar.dateComponents([.hour, .minute, .second], from: rhs)
            
            if lhsComponents.hour != rhsComponents.hour {
                return (lhsComponents.hour ?? 0) < (rhsComponents.hour ?? 0)
            } else if lhsComponents.minute != rhsComponents.minute {
                return (lhsComponents.minute ?? 0) < (rhsComponents.minute ?? 0)
            } else {
                return (lhsComponents.second ?? 0) < (rhsComponents.second ?? 0)
            }
        }
    }
    
    private var endTimeRecommendations: [Date] {
        var added: [Date] = []
        let allSuggestions = TimeTableManager.shared.schedule?.days.flatMap { day in
            day.classes.compactMap {
                let candidate = $0.time.end.asToday
                if !added.contains(candidate) {
                    added.append(candidate)
                    return candidate
                } else {
                    return nil
                }
            }
        }
        
        return (allSuggestions ?? []).sorted { lhs, rhs in
            let calendar = Calendar.current
            let lhsComponents = calendar.dateComponents([.hour, .minute, .second], from: lhs)
            let rhsComponents = calendar.dateComponents([.hour, .minute, .second], from: rhs)
            
            if lhsComponents.hour != rhsComponents.hour {
                return (lhsComponents.hour ?? 0) < (rhsComponents.hour ?? 0)
            } else if lhsComponents.minute != rhsComponents.minute {
                return (lhsComponents.minute ?? 0) < (rhsComponents.minute ?? 0)
            } else {
                return (lhsComponents.second ?? 0) < (rhsComponents.second ?? 0)
            }
        }
    }

    private var lessonSuggestions: [TimeTableLesson] {
        var added: [TimeTableLesson] = []
        let allSuggestions = TimeTableManager.shared.schedule?.days.flatMap({ $0.classes.compactMap({ classItem in
            if !added.contains(where: { $0.name == classItem.lesson.name && $0.color == classItem.lesson.color && $0.teacherName == classItem.lesson.teacherName && $0.roomName == classItem.lesson.roomName }) {
                added.append(classItem.lesson)
                return classItem.lesson
            } else {
                return nil
            }
        }) })
        return allSuggestions?.filter({ $0.name.lowercased().contains(lesson.name.lowercased()) }) ?? []
    }
    
    var teacherSuggestions: [String] {
        guard let currentTeacherName = lesson.teacherName else { return [] }
        var added: [String] = []
        
        let allSuggestions = TimeTableManager.shared.schedule?.days.flatMap({ $0.classes.compactMap({
            if let teacherName = $0.lesson.teacherName, !added.contains(teacherName) {
                added.append(teacherName)
                return teacherName
            } else {
                return nil
            }
        }) })
        
        return allSuggestions?.filter({ $0.lowercased().contains(currentTeacherName.lowercased()) }) ?? []
    }
    var isTimeValid: Bool {
        let startTotal = selectedTime.start.hour * 60 + selectedTime.start.minute
        let endTotal = selectedTime.end.hour * 60 + selectedTime.end.minute
        return endTotal > startTotal
    }
    private func addLesson() {
        // Validate
        guard isTimeValid else { return }
        lesson.name = lesson.name.trimmingCharacters(in: .whitespacesAndNewlines)
        // Ensure schedule exists
        let manager = TimeTableManager.shared
        var schedule = manager.schedule ?? TimeTableSchedule(id: UUID(), days: TimeTableSchedule.Days.allCases.map { TimeTableSchedule.TimeTableDay(day: $0, classes: []) })

        // Build new class
        let newClass = ScheduleClass(time: selectedTime, lesson: lesson, forceDoubleLesson: forceDoubleLesson)

        // Insert into the correct day
        if let idx = schedule.days.firstIndex(where: { $0.day == selectedTime.day }) {
            schedule.days[idx].classes.append(newClass)
            // Sort by start time
            schedule.days[idx].classes.sort { lhs, rhs in
                let lmins = lhs.time.start.hour * 60 + lhs.time.start.minute
                let rmins = rhs.time.start.hour * 60 + rhs.time.start.minute
                return lmins < rmins
            }
        }

        // Save
        manager.schedule = schedule
        // Dismiss
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
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)

                Spacer()
                Text("Edit Lesson")
                    .bold()
                Spacer()
                Button("Done") {
                    saveEdits()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(lesson.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isTimeValid)
            }
            .padding()
            Form {
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
                                Text("No Suggestions")
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(lessonSuggestions) { suggestion in
                                suggestionView(for: suggestion, lesson: $lesson)
                            }
                        } else {
                            Text("Start typing to see Suggestions...")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Schedule Time") {
                    Picker("Day", selection: $selectedTime.day) {
                        ForEach(TimeTableSchedule.Days.allCases, id: \.self) { day in
                            Text(day.name)
                                .tag(day)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        DatePicker("Start Time", selection: $selectedTime.startDate,  displayedComponents: .hourAndMinute)
                        Menu {
                            ForEach(startTimeRecommendations, id: \.self) { time in
                                Button(action: {
                                    selectedTime.startDate = time
                                }) {
                                    Text(time, formatter: timeFormatter)
                                }
                            }
                        } label: {
                            HStack {
                                Text("Recommendations")
                                Spacer()
                                Text(startTimeRecommendations.count, format: .number)
                                Image(systemName: "chevron.down")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .contentShape(.rect)
                        }
                        .disabled(startTimeRecommendations.isEmpty)
                        .menuStyle(.button)
                        .buttonStyle(.plain)
                    }
                    
                    VStack(alignment: .leading) {
                        DatePicker("End Time", selection: $selectedTime.endDate, displayedComponents: .hourAndMinute)
                        Menu {
                            ForEach(endTimeRecommendations, id: \.self) { time in
                                Button(action: {
                                    selectedTime.endDate = time
                                }) {
                                    Text(time, formatter: timeFormatter)
                                }
                            }
                        } label: {
                            HStack {
                                Text("Recommendations")
                                Spacer()
                                Text(endTimeRecommendations.count, format: .number)
                                Image(systemName: "chevron.down")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .contentShape(.rect)
                        }
                        .disabled(endTimeRecommendations.isEmpty)
                        .menuStyle(.button)
                        .buttonStyle(.plain)
                    }
                    
                    if !isTimeValid {
                        Label("End time must be after start time", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.footnote)
                    }
                    
                    VStack(alignment: .leading) {
                        Toggle("Double Lesson", isOn: $forceDoubleLesson)
                        Text("Makes SchoolTool to treat this Class as Double Lesson")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
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
                                                .foregroundStyle(.secondary)
                                                .padding(.horizontal)
                                        }
                                        ForEach(teacherSuggestions, id: \.self) { teacher in
                                            Button(teacher) { lesson.teacherName = teacher }
                                            if teacher != teacherSuggestions.last {
                                                Divider()
                                            }
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

    func suggestionView(for suggestion: TimeTableLesson, lesson: Binding<TimeTableLesson>) -> some View {
        Button(action: {
            withAnimation() {
                lesson.wrappedValue.name = suggestion.name
                lesson.wrappedValue.color = suggestion.color
                if let suggestedTeacherName = suggestion.teacherName {
                    lesson.wrappedValue.teacherName = suggestedTeacherName
                }
                if let roomName = suggestion.roomName {
                    lesson.wrappedValue.roomName = roomName
                }
                lesson.wrappedValue.symbol = suggestion.symbol
                nameFocused = false
            }
        }) {
            HStack(alignment: .center) {
                Image(systemName: suggestion.symbol)
                    .foregroundStyle(.primary)
                    .frame(width: 25)
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        if let teacher = suggestion.teacherName, !teacher.isEmpty {
                            Text(teacher)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let room = suggestion.roomName, !room.isEmpty {
                            if suggestion.teacherName != nil {
                                Divider()
                            }
                            Text("Room \(room)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                if lesson.wrappedValue == suggestion {
                    Image(systemName: "checkmark")
                } else {
                    Circle()
                        .fill(suggestion.color)
                        .frame(width: 10, height: 10)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
    
    private var startTimeRecommendations: [Date] {
        var added: [Date] = []
        let allSuggestions = TimeTableManager.shared.schedule?.days.flatMap { day in
            day.classes.compactMap {
                let candidate = $0.time.start.asToday
                if !added.contains(candidate) {
                    added.append(candidate)
                    return candidate
                } else {
                    return nil
                }
            }
        }
        
        return (allSuggestions ?? []).sorted { lhs, rhs in
            let calendar = Calendar.current
            let lhsComponents = calendar.dateComponents([.hour, .minute, .second], from: lhs)
            let rhsComponents = calendar.dateComponents([.hour, .minute, .second], from: rhs)
            
            if lhsComponents.hour != rhsComponents.hour {
                return (lhsComponents.hour ?? 0) < (rhsComponents.hour ?? 0)
            } else if lhsComponents.minute != rhsComponents.minute {
                return (lhsComponents.minute ?? 0) < (rhsComponents.minute ?? 0)
            } else {
                return (lhsComponents.second ?? 0) < (rhsComponents.second ?? 0)
            }
        }
    }
    
    private var endTimeRecommendations: [Date] {
        var added: [Date] = []
        let allSuggestions = TimeTableManager.shared.schedule?.days.flatMap { day in
            day.classes.compactMap {
                let candidate = $0.time.end.asToday
                if !added.contains(candidate) {
                    added.append(candidate)
                    return candidate
                } else {
                    return nil
                }
            }
        }
        
        return (allSuggestions ?? []).sorted { lhs, rhs in
            let calendar = Calendar.current
            let lhsComponents = calendar.dateComponents([.hour, .minute, .second], from: lhs)
            let rhsComponents = calendar.dateComponents([.hour, .minute, .second], from: rhs)
            
            if lhsComponents.hour != rhsComponents.hour {
                return (lhsComponents.hour ?? 0) < (rhsComponents.hour ?? 0)
            } else if lhsComponents.minute != rhsComponents.minute {
                return (lhsComponents.minute ?? 0) < (rhsComponents.minute ?? 0)
            } else {
                return (lhsComponents.second ?? 0) < (rhsComponents.second ?? 0)
            }
        }
    }
    
    private var lessonSuggestions: [TimeTableLesson] {
        var added: [TimeTableLesson] = []
        let allSuggestions = TimeTableManager.shared.schedule?.days.flatMap({ $0.classes.compactMap({ classItem in
            if !added.contains(where: { $0.name == classItem.lesson.name && $0.color == classItem.lesson.color && $0.teacherName == classItem.lesson.teacherName && $0.roomName == classItem.lesson.roomName }) {
                added.append(classItem.lesson)
                return classItem.lesson
            } else {
                return nil
            }
        }) })
        return allSuggestions?.filter({ $0.name.lowercased().contains(lesson.name.lowercased()) }) ?? []
    }

    private var teacherSuggestions: [String] {
        guard let currentTeacherName = lesson.teacherName else { return [] }
        var added: [String] = []
        let allSuggestions = TimeTableManager.shared.schedule?.days.flatMap({ $0.classes.compactMap({
            if let teacherName = $0.lesson.teacherName, !added.contains(teacherName) {
                added.append(teacherName)
                return teacherName
            } else {
                return nil
            }
        }) })
        return allSuggestions?.filter({ $0.lowercased().contains(currentTeacherName.lowercased()) }) ?? []
    }

    private var isTimeValid: Bool {
        let startTotal = selectedTime.start.hour * 60 + selectedTime.start.minute
        let endTotal = selectedTime.end.hour * 60 + selectedTime.end.minute
        return endTotal > startTotal
    }

    private func saveEdits() {
        guard isTimeValid else { return }
        let trimmedName = lesson.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        lesson.name = trimmedName

        let manager = TimeTableManager.shared
        guard var schedule = manager.schedule else { return }

        // Locate original day and index
        guard let originalDayIndex = schedule.days.firstIndex(where: { $0.day == original.time.day }),
              let originalClassIndex = schedule.days[originalDayIndex].classes.firstIndex(where: { $0.id == original.id }) else { return }

        let updated = ScheduleClass(id: original.id, time: selectedTime, lesson: lesson, forceDoubleLesson: forceDoubleLesson)

        // If day unchanged, replace in-place then sort
        if selectedTime.day == original.time.day {
            schedule.days[originalDayIndex].classes[originalClassIndex] = updated
            schedule.days[originalDayIndex].classes.sort { lhs, rhs in
                let lmins = lhs.time.start.hour * 60 + lhs.time.start.minute
                let rmins = rhs.time.start.hour * 60 + rhs.time.start.minute
                return lmins < rmins
            }
        } else {
            // Move across days
            schedule.days[originalDayIndex].classes.remove(at: originalClassIndex)
            if let newDayIndex = schedule.days.firstIndex(where: { $0.day == selectedTime.day }) {
                schedule.days[newDayIndex].classes.append(updated)
                schedule.days[newDayIndex].classes.sort { lhs, rhs in
                    let lmins = lhs.time.start.hour * 60 + lhs.time.start.minute
                    let rmins = rhs.time.start.hour * 60 + rhs.time.start.minute
                    return lmins < rmins
                }
            }
        }

        manager.schedule = schedule
        dismiss()
    }
}
#endif

extension View {
    func navStacked() -> some View {
        NavigationStack { self }
    }
}

#Preview {
    ContentView()
}
#if os(macOS)
import AppKit
#endif

extension View {
    func dragAction(_ action: @escaping (DragActionModifier.Side) -> Void) -> some View {
        modifier(DragActionModifier(action: action))
    }
}

struct DragActionModifier: ViewModifier {
    enum DragDirection {
        case undecided
        case horizontal
        case vertical
    }
    enum Side {
        case left
        case right
    }

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
                            withAnimation {
                                disableAllOtherGestures = true
                            }
                        }
                        withAnimation {
                            if xOffset >= 200 && !playedHaptic {
                                playHaptic()
                                playedHaptic = true
                            } else if xOffset <= -200 && !playedHaptic {
                                playHaptic()
                                playedHaptic = true
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
                        
                        let dragSide: Side = xOffset < 0 ? .right : .left
                        if self.dragSide != dragSide {
                            self.dragSide = dragSide
                        }
                        
                    }
                    .onEnded { _ in
                        if direction == .horizontal  {
                            if xOffset >= 200 {
                                action(.left)
                            }
                            if xOffset <= -200 {
                                action(.right)
                            }
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
                                Circle()
                                    .stroke(.gray.opacity(playedHaptic ? 0.25 : 0))
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
