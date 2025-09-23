//
//  ContentView.swift
//  SchoolTool Watch Watch App
//
//  Created by Tim on 20.09.25.
//

import SwiftUI
import WidgetKit

struct ContentView: View {
    @StateObject var manager = TimeTableManager.shared
    @State private var selectedDay: TimeTableSchedule.Days = TimeTableSchedule.Days.today
    @AppStorage("skipEmptyDays") var skipEmptyDays = false
    @State var resetAppAlert = false
    var body: some View {
        NavigationStack {
            if let schedule = manager.schedule {
                TabView {
                    TabView(selection: $selectedDay) {
                        ForEach(schedule.days, id: \.day) { day in
                            if day.classes.isEmpty {
                                if !skipEmptyDays {
                                    ContentUnavailableView("No Classes yet", systemImage: "text.badge.plus", description: Text("Try syncing or add classes on iPhone"))
                                        .tag(day.day)
                                }
                            } else {
                                List {
                                    Section(day.day.name) {
                                        ForEach(day.classes) { item in
                                            NavigationLink {
                                                LessonDetailView(item: item)
                                            } label: {
                                                CompactLessonRow(item: item)
                                            }
                                            .listRowBackground(LinearGradient(colors: [item.lesson.color.opacity(0.25), item.lesson.color.opacity(0.75)], startPoint: .top, endPoint: .bottom).cornerRadius(5))
                                        }
                                    }
                                }
                                .listStyle(.carousel)
                                .tag(day.day)
                                .scrollContentBackground(.hidden)
                            }
                        }
                    }
                    .tabViewStyle(.page)
                    .navigationTitle("TimeTable")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            if manager.awaitingSync {
                                ProgressView()
                            }
                        }
                    }
                    ScrollView {
                        Button("Force Sync") {
                            manager.request()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        Button("Reset App") {
                            resetAppAlert.toggle()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        Button("Skip Empty Days") {
                            withAnimation() {
                                skipEmptyDays.toggle()
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(skipEmptyDays ? .green : .red)
                    }
                    .alert("Are you sure?", isPresented: $resetAppAlert) {
                        Button("Yes", role: .destructive) {
                            manager.schedule = nil
                            resetAppAlert = false
                        }
                        Button("Cancel", role: .cancel) {
                            resetAppAlert = false
                        }
                    } message: {
                        Text("This cannot be undone")
                    }

                }
                .tabViewStyle(.verticalPage)
            } else {
                VStack {
                    ContentUnavailableView("No Schedule yet", systemImage: "calendar", description: Text("Try Force Syncing!"))
                    Button("Force Sync") {
                        manager.request()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if manager.awaitingSync {
                            ProgressView()
                        }
                    }
                }
                .onAppear {
                    manager.request()
                }
            }
        }
        .background {
            LinearGradient(colors: [.clear, .gray.opacity(0.35)], startPoint: .bottom, endPoint: .top)
                .ignoresSafeArea(.all)
        }
    }
}

// Compact row for class/lesson on watch
struct CompactLessonRow: View {
    var item: ScheduleClass
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.lesson.symbol)
                .foregroundStyle(item.lesson.color)
            VStack(alignment: .leading, spacing: 0) {
                Text(item.lesson.name)
                    .bold()
                    .lineLimit(1)
                Text("\(timeString(item.time))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
    func timeString(_ time: TimeTableTime) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(formatter.string(from: time.startDate)) – \(formatter.string(from: time.endDate))"
    }
}

// Detail for a lesson/class
struct LessonDetailView: View {
    var item: ScheduleClass
    var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = .none
        formatter.timeStyle = .short
        return formatter
    }
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
        .scrollContentBackground(.hidden)
        .background(LinearGradient(colors: [item.lesson.color.opacity(0.25), item.lesson.color.opacity(0.75)], startPoint: .top, endPoint: .bottom), ignoresSafeAreaEdges: .all)
        .navigationTitle("Details")
    }
}

#Preview {
    ContentView()
}
