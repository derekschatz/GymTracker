import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }

            NutritionView()
                .tabItem { Label("Nutrition", systemImage: "fork.knife") }

            WorkoutView()
                .tabItem { Label("Workout", systemImage: "dumbbell.fill") }
        }
        .tint(.blue)
        .fullScreenCover(isPresented: $store.isWorkoutPresented) {
            ActiveWorkoutView()
        }
    }
}
