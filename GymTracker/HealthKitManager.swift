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

    func saveCardio(_ entry: CardioEntry) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        do {
            try await healthStore.requestAuthorization(
                toShare: [HKWorkoutType.workoutType()],
                read: []
            )

            let workout = HKWorkout(
                activityType: activityType(for: entry.activity),
                start: entry.date,
                end: entry.date.addingTimeInterval(max(entry.duration, 60)),
                duration: max(entry.duration, 60),
                totalEnergyBurned: nil,
                totalDistance: entry.distance.map {
                    HKQuantity(unit: .mile(), doubleValue: $0)
                },
                metadata: nil
            )

            try await healthStore.save(workout)
        } catch {
            print("HealthKit cardio save failed: \(error)")
        }
    }

    private func activityType(for activity: CardioActivity) -> HKWorkoutActivityType {
        switch activity {
        case .run: return .running
        case .walk: return .walking
        case .cycle: return .cycling
        case .swim: return .swimming
        case .row: return .rowing
        case .elliptical: return .elliptical
        case .stairs: return .stairClimbing
        case .hike: return .hiking
        case .sport, .other: return .other
        }
    }
}
