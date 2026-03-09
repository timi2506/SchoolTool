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
                    // TimeTable page – swipe horizontally between days
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

                    // Settings page – swipe down
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
                .tabViewStyle(.verticalPage)
            } else {
                VStack {
                    ContentUnavailableView(
                        "No Schedule yet",
                        systemImage: "calendar",
                        description: Text("Try Force Syncing!")
                    )
                    Button("Force Sync") {
                        manager.request()
                    }
                    .borderedProminent()
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

    private func timeRangeString(_ item: ScheduleClass) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(formatter.string(from: item.time.startDate)) – \(formatter.string(from: item.time.endDate))"
    }
}

#Preview {
    ContentView()
}
