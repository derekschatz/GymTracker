import SwiftUI

@main
struct GymTrackerApp: App {
    @StateObject private var store = AppStore.shared
    @StateObject private var watchManager = PhoneToWatchManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(watchManager)
        }
    }
}
