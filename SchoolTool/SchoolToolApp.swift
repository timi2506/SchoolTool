//
//  SchoolToolApp.swift
//  SchoolTool
//
//  Created by Tim on 17.09.25.
//

import SwiftUI

@main
struct SchoolToolApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
