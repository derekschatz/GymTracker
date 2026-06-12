import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(0)

            CoachView()
                .tabItem { Label("Coach", systemImage: "sparkles") }
                .tag(1)

            NutritionView()
                .tabItem { Label("Nutrition", systemImage: "fork.knife") }
                .tag(2)

            WorkoutView()
                .tabItem { Label("Workout", systemImage: "dumbbell.fill") }
                .tag(3)
        }
        .tint(.indigo)
        .fullScreenCover(isPresented: $store.isWorkoutPresented) {
            ActiveWorkoutView()
        }
        .fullScreenCover(isPresented: needsOnboarding) {
            OnboardingView()
        }
    }

    private var needsOnboarding: Binding<Bool> {
        Binding(
            get: { store.profile == nil },
            set: { _ in }
        )
    }
}
