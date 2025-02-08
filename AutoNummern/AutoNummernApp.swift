//
//  AutoNummernApp.swift
//  AutoNummern
//
//  Created by Kira Hennig on 22.12.23.
//

import SwiftUI

/* Dies ist ein Testkommentar der gleich über Git committed wird */

@main
struct AutoNummernApp: App {
    
    // Create an observable instance of the Core Data stack.
    // @StateObject private var coreDataStack = CoreDataStack.shared

    // Delegate to accept share requests - muss genutzt werden damit die aktuelle Autonummer unter allen Teilnehmern aus getauscht werden kann.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
            // Inject the persistent container's managed object context
            // into the environment.
                .environment(\.managedObjectContext,
                              CoreDataStack.shared.context)
        }
    }
}



