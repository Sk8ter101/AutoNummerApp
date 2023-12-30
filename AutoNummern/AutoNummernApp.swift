//
//  AutoNummernApp.swift
//  AutoNummern
//
//  Created by Kira Hennig on 22.12.23.
//

import SwiftUI
import UserNotifications

@main
struct AutoNummernApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    registerForPushNotifications()
    return true
}


