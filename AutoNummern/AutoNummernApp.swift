//
//  AutoNummernApp.swift
//  AutoNummern
//
//  Created by Kira Hennig on 22.12.23.
//

import SwiftUI

@main
struct AutoNummernApp: App {
    // Delegate akzeptiert Share-Einladungen, damit die aktuelle Autonummer
    // unter allen Teilnehmern ausgetauscht werden kann.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, CoreDataStack.shared.context)
        }
    }
}
