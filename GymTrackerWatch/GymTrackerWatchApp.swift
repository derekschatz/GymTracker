import SwiftUI

@main
struct GymTrackerWatchApp: App {
    @StateObject private var workoutManager = WatchWorkoutManager.shared

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(workoutManager)
        }
    }
}
