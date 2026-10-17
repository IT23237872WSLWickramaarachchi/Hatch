//
//  HatchApp.swift
//  Hatch
//
//  Created by IM Student on 2026-10-17.
//

import SwiftUI

@main
struct HatchApp: App {
    @StateObject private var persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistence.viewContext)
                .environmentObject(persistence)
        }
    }
}
