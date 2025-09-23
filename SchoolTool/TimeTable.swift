import SwiftUI
import Combine

struct TimeTableView: View {
    @StateObject var timeTableManager = TimeTableManager.shared

    @State var addSchedule = false
    @State var selectedDay: TimeTableSchedule.Days?
    var body: some View {
        VStack {
            if let schedule = timeTableManager.schedule {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 0) {
                            ForEach(schedule.days) { day in
                                DayColumnView(day: day, proxy: proxy, selectedDay: $selectedDay)
                                    .containerRelativeFrame(.horizontal)
                                    .id(day.day)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollIndicators(.never)
                    .scrollPosition(id: $selectedDay)
                }
            } else {
                ContentUnavailableView("Time Table not configured", systemImage: "calendar")
            }
        }
        .navigationTitle("Time Table")
        .toolbar {
            #if os(iOS)
            EditButton()
            #endif
            Button("Add", systemImage: "plus") {
                addSchedule.toggle()
            }
            .labelStyle(.iconOnly)
        }
        .sheet(isPresented: $addSchedule) {
            AddScheduleView(selectedTime: .init(day: selectedDay ?? .monday, start: .init(from: Date()), end: .init(from: Date().addingTimeInterval(3600))))
        }
        .navStacked()
    }
}

struct DayColumnView: View {
    @StateObject private var manager = TimeTableManager.shared
    @AppStorage("fullColorRow") var fullColorRow = false

    var day: TimeTableSchedule.TimeTableDay
    var proxy: ScrollViewProxy
    @Binding var selectedDay: TimeTableSchedule.Days?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Previous Day", systemImage: "chevron.left") {
                    withAnimation() {
                        proxy.scrollTo(day.day.yesterday.id)
                        selectedDay = day.day.yesterday
                    }
                }
                .font(.title2).bold()
                .labelStyle(.iconOnly)
                Spacer()
                Text(day.day.name)
                    .font(.title2).bold()
                Spacer()
                Button("Next Day", systemImage: "chevron.right") {
                    withAnimation() {
                        proxy.scrollTo(day.day.tomorrow.id)
                        selectedDay = day.day.tomorrow
                    }
                }
                .font(.title2).bold()
                .labelStyle(.iconOnly)
            }
            .padding()
            if day.classes.isEmpty {
                ContentUnavailableView("No Classes yet", systemImage: "text.badge.plus", description: Text("Try adding some"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Form {
                    Section("Classes") {
                        ForEach(day.classes) { item in
                            LessonRow(item: item) {
                                delete(item)
                            }
#if os(iOS)
                            .listRowBackground(fullColorRow ? LinearGradient(colors: [item.lesson.color.opacity(0.25), item.lesson.color.opacity(0.75)], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom))
#endif
                        }
                        .onDelete { indexSet in
                            delete(at: indexSet)
                        }
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
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
        .scrollContentBackground(.hidden)
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
        #if os(iOS)
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
            HStack(alignment: .center) {
                Image(systemName: item.lesson.symbol)
                    .foregroundStyle(primary)
                    .frame(width: 25)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.lesson.name)
                        .font(.headline)
                        .foregroundStyle(primary)
                    HStack(spacing: 8) {
                        Text(timeRangeString(item))
                            .font(.subheadline)
                            .foregroundStyle(secondary)
                        if let teacher = item.lesson.teacherName, !teacher.isEmpty {
                            Divider()
                            Text(teacher)
                                .font(.subheadline)
                                .foregroundStyle(secondary)
                        }
                        if let room = item.lesson.roomName, !room.isEmpty {
                            Divider()
                            Text("Room \(room)")
                                .font(.subheadline)
                                .foregroundStyle(secondary)
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
            .padding(.vertical, 5)
            .contentShape(.rect)
            .contextMenu {
                Button {
                    showEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .sheet(isPresented: $showEditor) {
                LessonEditorView(original: item)
            }
        }
        .buttonStyle(.plain)
    }

    private func timeRangeString(_ item: ScheduleClass) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(formatter.string(from: item.time.startDate)) – \(formatter.string(from: item.time.endDate))"
    }
}

import SymbolPicker

struct AddScheduleView: View {
    @Environment(\.dismiss) var dismiss
    @State var selectedTime = TimeTableTime(day: .monday, start: .init(from: Date()), end: .init(from: Date().addingTimeInterval(3600)))
    @State var lesson: TimeTableLesson = .init(name: "", teacherName: nil, roomName: nil, color: .blue)
    @FocusState var nameFocused: Bool
    @FocusState var teacherFocused: Bool
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
        let newClass = ScheduleClass(time: selectedTime, lesson: lesson)

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

    private let original: ScheduleClass

    init(original: ScheduleClass) {
        self._selectedTime = State(initialValue: original.time)
        self._lesson = State(initialValue: original.lesson)
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

        let updated = ScheduleClass(id: original.id, time: selectedTime, lesson: lesson)

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

extension View {
    func navStacked() -> some View {
        NavigationStack { self }
    }
}

#Preview {
    ContentView()
}
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif
import Drops
#if os(iOS)
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
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
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
    }
    @Published var schedule: TimeTableSchedule? {
        didSet {
            save()
        }
    }
    @Published var watchAppVersionString: String?
    @Published var waitingForVersionString = false
    @AppStorage("watchLastSynced") var lastSynced: String?
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
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(messageDict, replyHandler: nil) { error in
                print("Failed to send message", error.localizedDescription)
            }
        } else {
            WCSession.default.transferUserInfo(messageDict)
        }
    }
    func sendToAppleWatch(_ data: Data? = nil) {
        let encoder = JSONEncoder()
        guard let encodedSchedule = data ?? (try? encoder.encode(schedule)) else { return }
        var errorOccured = false
        // Remove all pending first
        WCSession.default.outstandingUserInfoTransfers.forEach({ $0.cancel() })
        let messageDict = ["timetable_schedule": encodedSchedule]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(messageDict, replyHandler: nil) { error in
                print("Failed to send message:", error.localizedDescription)
                errorOccured = true
            }
            let drop = Drop(title: "Schedule Synced to Watch", subtitle: "Apple Watch synced successfully", icon: UIImage(systemName: "checkmark.circle.fill")!, position: .bottom)
            if !errorOccured {
                Drops.hideAll()
                Drops.show(drop)
                lastSynced = Date().formatted(date: .long, time: .shortened)
            }
        } else {
            // fallback: send as background transfer
            WCSession.default.transferUserInfo(messageDict)
            let drop = Drop(title: "Schedule will Sync to Watch", subtitle: "When connected", icon: UIImage(systemName: "checkmark.circle.fill")!, position: .bottom)
            if !errorOccured {
                Drops.hideAll()
                Drops.show(drop)
                lastSynced = Date().formatted(date: .long, time: .shortened)
            }
        }
    }
    // Receiving messages
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let request = message["request"] as? String {
            DispatchQueue.main.async {
                switch request {
                    case "timetable_schedule": self.sendToAppleWatch()
                    default:
                        print("Unknown Request")
                }
            }
        } else if let appVersionString = message["appVersionString"] as? String {
            watchAppVersionString = appVersionString
            waitingForVersionString = false
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        if let request = userInfo["request"] as? String {
            DispatchQueue.main.async {
                switch request {
                    case "timetable_schedule": self.sendToAppleWatch()
                    default:
                        print("Unknown Request")
                }
            }
        } else if let appVersionString = userInfo["appVersionString"] as? String {
            watchAppVersionString = appVersionString
            waitingForVersionString = false
        }
    }
}
#elseif os(macOS)
/// Class Holding All TimeTable Data
class TimeTableManager: ObservableObject {
    /// Shared TimeTable Manager
    static let shared = TimeTableManager()
    /// Use Shared Manager Instead
    init() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.shared.data(forKey: "schoolToolSchedule"), let existing = try? decoder.decode(TimeTableSchedule.self, from: data) {
            self.schedule = existing
        }
    }
    @Published var schedule: TimeTableSchedule? {
        didSet {
            save()
        }
    }
    func save() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(schedule) {
            UserDefaults.shared.set(encoded, forKey: "schoolToolSchedule")
        }
    }
}
#endif

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

