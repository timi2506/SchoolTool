//
//  ContentView.swift
//  SchoolTool
//
//  Created by Tim on 17.09.25.
//

import SwiftUI

struct ContentView: View {
    @StateObject var timeTableManager = TimeTableManager.shared

    var body: some View {
        TabView {
            PDFToolView()
                .tabItem {
                    Label("PDF Tool", systemImage: "document")
                }
            TimeTableView()
                .tabItem {
                    Label("Time Table", systemImage: "calendar")
                }
            #if os(iOS)
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
            #endif
        }
        #if os(macOS)
        .tabViewStyle(.sidebarAdaptable)
        #elseif os(iOS)
        .onAppear {
            timeTableManager.sendToAppleWatch()
        }
        #endif
    }
}

#Preview {
    ContentView()
}
