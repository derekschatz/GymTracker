import Foundation
import HealthKit

/// Best-effort sync of finished workouts to Apple Health. Failures are
/// logged and never interrupt the app.
final class HealthKitManager {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()

    private init() {}

    func saveWorkout(_ workout: Workout) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        do {
            try await healthStore.requestAuthorization(
                toShare: [HKWorkoutType.workoutType()],
                read: []
            )

            let duration = max(workout.duration, 60)
            let endDate = workout.date.addingTimeInterval(duration)

            let hkWorkout = HKWorkout(
                activityType: .traditionalStrengthTraining,
                start: workout.date,
                end: endDate,
                duration: duration,
                totalEnergyBurned: nil,
                totalDistance: nil,
                metadata: [
                    "name": workout.name,
                    "totalVolume": workout.totalVolume,
                    "exerciseCount": workout.exercises.count
                ]
            )

            try await healthStore.save(hkWorkout)
        } catch {
            print("HealthKit save failed: \(error)")
        }
    }
}
