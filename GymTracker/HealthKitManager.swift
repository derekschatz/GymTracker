import Foundation
import HealthKit
import Combine

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false

    private init() {}

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        let typesToShare: Set<HKSampleType> = [
            HKWorkoutType.workoutType()
        ]

        let typesToRead: Set<HKObjectType> = [
            HKWorkoutType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]

        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
        await MainActor.run {
            isAuthorized = true
        }
    }

    func saveWorkout(_ session: SessionRecord) async throws {
        let startDate = session.date
        let endDate = startDate.addingTimeInterval(session.duration ?? 3600)

        let workout = HKWorkout(
            activityType: .traditionalStrengthTraining,
            start: startDate,
            end: endDate,
            duration: session.duration ?? 3600,
            totalEnergyBurned: session.calories.map {
                HKQuantity(unit: .kilocalorie(), doubleValue: $0)
            },
            totalDistance: nil,
            metadata: [
                "planName": session.planName,
                "totalVolume": session.totalVolume,
                "exerciseCount": session.exercises.count
            ]
        )

        try await healthStore.save(workout)
    }

    func fetchRecentWorkouts(limit: Int = 10) async throws -> [HKWorkout] {
        let workoutType = HKWorkoutType.workoutType()
        let predicate = HKQuery.predicateForWorkouts(with: .traditionalStrengthTraining)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let workouts = samples as? [HKWorkout] ?? []
                continuation.resume(returning: workouts)
            }

            healthStore.execute(query)
        }
    }

    enum HealthKitError: Error {
        case notAvailable
        case notAuthorized
    }
}
