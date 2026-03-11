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
            TimeTableView()
                .tabItem {
                    Label("Time Table", systemImage: "calendar")
                }
#if os(macOS) || os(iOS)
            PDFToolView()
                .tabItem {
                    Label("PDF Tool", systemImage: "document")
                }
            FeedsView()
                .tabItem {
                    Label("Feeds", systemImage: "dot.radiowaves.up.forward")
                }
#endif
#if os(iOS) || os(tvOS)
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
