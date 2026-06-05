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
            // Migration failed — delete the store and start fresh rather than
            // crashing. Checks both the app container and the App Group container.
            let candidates: [URL] = [
                FileManager.default
                    .containerURL(forSecurityApplicationGroupIdentifier: "group.br.com.devbrains.SignatureWidgets")?
                    .appendingPathComponent("Library/Application Support/default.store"),
                FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                    .appendingPathComponent("default.store")
            ].compactMap { $0 }

            for base in candidates {
                for suffix in ["", "-shm", "-wal"] {
                    try? FileManager.default.removeItem(at: URL(fileURLWithPath: base.path + suffix))
                }
            }

            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not create ModelContainer even after reset: \(error)")
            }
        }
    }()

    init() {
        loadRocketSimConnect()
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

// MARK: - RocketSim

private func loadRocketSimConnect() {
    #if DEBUG
    guard (Bundle(path: "/Applications/RocketSim.app/Contents/Frameworks/RocketSimConnectLinker.nocache.framework")?.load() == true) else {
        print("Failed to load linker framework")
        return
    }
    print("RocketSim Connect successfully linked")
    #endif
}
