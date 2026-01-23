//
//  GymTrackerApp.swift
//  GymTracker
//
//  Created by Derek Schatz on 1/21/26.
//

import SwiftUI

@main
struct GymTrackerApp: App {
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var watchManager = PhoneToWatchManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
                .environmentObject(healthKitManager)
                .environmentObject(watchManager)
                .onAppear {
                    print("✅ App launched successfully!")
                }
        }
    }
}
