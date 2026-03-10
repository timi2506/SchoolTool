//
//  SchoolTool_WatchApp.swift
//  SchoolTool Watch Watch App
//
//  Created by Tim on 20.09.25.
//

import SwiftUI
import AppIntents
import WidgetKit

@main
struct SchoolTool_Watch_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    WidgetCenter.shared.reloadAllTimelines()
                }
        }
    }
}
