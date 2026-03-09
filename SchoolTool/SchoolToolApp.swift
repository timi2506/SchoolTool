//
//  SchoolToolApp.swift
//  SchoolTool
//
//  Created by Tim on 17.09.25.
//

import SwiftUI
#if os(iOS) || os(macOS)
import WidgetKit
#endif

@main
struct SchoolToolApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
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

#if os(iOS)
import Drops

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem {
            handleQuickActionItem(shortcutItem)
        }
        let sceneConfiguration = UISceneConfiguration(name: "Custom Configuration", sessionRole: connectingSceneSession.role)
        sceneConfiguration.delegateClass = CustomSceneDelegate.self
        
        return sceneConfiguration
    }
}

class CustomSceneDelegate: UIResponder, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        handleQuickActionItem(shortcutItem)
    }
}

func handleQuickActionItem(_ item: UIApplicationShortcutItem) {
    DispatchQueue.main.async {
        print(item.type)
        switch item.type {
            case "RefreshWidgets":
                WidgetCenter.shared.reloadAllTimelines()
                let drop = Drop(title: "Force Refresh Widgets", subtitle: "Refreshed Successfully", icon: UIImage(systemName: "checkmark.circle.fill")!, position: .top)
                Drops.hideAll()
                Drops.show(drop)
            default:
                print("Unknown Quick Action: \"\(item.type)\"")
        }
    }
}
#endif
