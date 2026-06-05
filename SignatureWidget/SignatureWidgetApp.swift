//
//  SignatureWidgetApp.swift
//  SignatureWidget
//

import SwiftUI
import SwiftData

@main
struct SignatureWidgetApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Signature.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Record first launch date for the 7-day trial clock
        TrialManager.recordFirstLaunchIfNeeded()
        // Kick off entitlement refresh in the background
        Task { await StoreManager.shared.refreshEntitlements() }
    }

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environmentObject(StoreManager.shared)
        }
        .modelContainer(sharedModelContainer)
    }
}
