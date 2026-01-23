import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager

    var body: some View {
        NavigationStack {
            if let workout = workoutManager.activeWorkout {
                WatchWorkoutView(workout: workout)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)

                    Text("GymTracker")
                        .font(.headline)

                    Text("Start a workout on your iPhone")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
    }
}
