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
            TabView {
                if let item = manager.currentClass {
                    VStack {
                        Spacer()
                        VStack(alignment: .center) {
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
                        .padding(.horizontal)
                        Spacer()
                        NavigationLink("Open Schedule") {
                            timeTableContentView
                        }
                        .borderedProminent()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LinearGradient(colors: [item.lesson.color.opacity(0.25), item.lesson.color.opacity(0.75)], startPoint: .top, endPoint: .bottom), ignoresSafeAreaEdges: .all)
                    .navigationTitle("TimeTable")
                } else {
                    NavigationLink {
                        timeTableContentView
                    } label: {
                        VStack {
                            Image(systemName: "calendar")
                                .font(.system(size: 75))
                                .bold()
                            Text("TimeTable")
                                .font(.headline)
                                .bold()
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
                NavigationLink {
                    settingsView
                } label: {
                    VStack {
                        Image(systemName: "gear")
                            .font(.system(size: 75))
                            .bold()
                        Text("Settings")
                            .font(.headline)
                            .bold()
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
        }
        .background {
            LinearGradient(colors: [.clear, .gray.opacity(0.35)], startPoint: .bottom, endPoint: .top)
                .ignoresSafeArea(.all)
        }
    }
    var settingsView: some View {
        Form {
            Section {
                Button("Force Sync", systemImage: "arrow.trianglehead.2.clockwise.rotate.90") {
                    manager.request()
                }
                .foregroundStyle(.blue)
            }
            Section {
                Toggle("Skip Empty Days", isOn: $skipEmptyDays.animation())
            }
            Section {
                Button("Reset App", systemImage: "trash") {
                    resetAppAlert.toggle()
                }
                .foregroundStyle(.red)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Settings")
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
    @ViewBuilder var timeTableContentView: some View {
        if let schedule = manager.schedule {
            timeTableView(for: schedule)
        } else {
            VStack {
                ContentUnavailableView("No Schedule yet", systemImage: "calendar", description: Text("Try Force Syncing!"))
                Button("Force Sync") {
                    manager.request()
                }
                .borderedProminent()
                .tint(.blue)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
    
    func timeTableView(for schedule: TimeTableSchedule) -> some View {
        TabView(selection: $selectedDay) {
            ForEach(schedule.days, id: \.day) { day in
                if day.classes.isEmpty {
                    if !skipEmptyDays {
                        ContentUnavailableView(
                            "No Classes",
                            systemImage: "text.badge.plus",
                            description: Text("Try syncing or add classes on iPhone")
                        )
                        .tag(day.day)
                    }
                } else {
                    List {
                        ForEach(day.classes) { item in
                            Section(timeRangeString(item)) {
                                NavigationLink {
                                    ClassDetailView(item: item)
                                } label: {
                                    LessonRowLabel(item: item)
                                }
                                .listRowBackground(
                                    LinearGradient(
                                        colors: [item.lesson.color.opacity(0.25), item.lesson.color.opacity(0.75)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .cornerRadius(5)
                                )
                            }
                        }
                    }
                    .listStyle(.carousel)
                    .tag(day.day)
                    .scrollContentBackground(.hidden)
                    .navigationTitle(day.day.name)
                }
            }
        }
        .tabViewStyle(.page)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if manager.awaitingSync {
                    ProgressView()
                }
            }
        }
    }
    
    private func timeString(_ time: TimeTableTime) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(formatter.string(from: time.startDate)) – \(formatter.string(from: time.endDate))"
    }

    private func timeRangeString(_ item: ScheduleClass) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(formatter.string(from: item.time.startDate)) – \(formatter.string(from: item.time.endDate))"
    }
}
