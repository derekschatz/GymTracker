import Foundation
import Combine

class DataManager: ObservableObject {
    static let shared = DataManager()

    @Published var plans: [WorkoutPlan] = []
    @Published var history: [SessionRecord] = []
    @Published var inProgressWorkout: InProgressWorkout? = nil

    private let plansKey = "gym_tracker_plans"
    private let historyKey = "gym_tracker_history"
    private let inProgressKey = "gym_tracker_in_progress"

    private init() {
        loadData()
    }

    // In-progress workout state for recovery
    struct InProgressWorkout: Codable {
        let planId: UUID
        let planName: String
        var exercises: [Exercise]
        let startTime: Date
        var currentExerciseIndex: Int
    }

    func loadData() {
        if let plansData = UserDefaults.standard.data(forKey: plansKey) {
            if let decoded = try? JSONDecoder().decode([WorkoutPlan].self, from: plansData) {
                plans = decoded
            }
        }

        if let historyData = UserDefaults.standard.data(forKey: historyKey) {
            if let decoded = try? JSONDecoder().decode([SessionRecord].self, from: historyData) {
                history = decoded
            }
        }

        if let inProgressData = UserDefaults.standard.data(forKey: inProgressKey) {
            if let decoded = try? JSONDecoder().decode(InProgressWorkout.self, from: inProgressData) {
                inProgressWorkout = decoded
            }
        }
    }

    func savePlans() {
        if let encoded = try? JSONEncoder().encode(plans) {
            UserDefaults.standard.set(encoded, forKey: plansKey)
        }
    }

    func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: historyKey)
        }
    }

    func addPlan(_ plan: WorkoutPlan) {
        plans.append(plan)
        savePlans()
    }

    func addPlans(_ newPlans: [WorkoutPlan]) {
        plans.append(contentsOf: newPlans)
        savePlans()
    }

    func deletePlan(_ plan: WorkoutPlan) {
        plans.removeAll { $0.id == plan.id }
        savePlans()
    }

    func addSession(_ session: SessionRecord) {
        history.insert(session, at: 0)
        saveHistory()
        // Clear in-progress workout since we've finished
        clearInProgressWorkout()
        // Update previous weights on the plan
        updatePreviousWeights(from: session)
    }

    // MARK: - In-Progress Workout Management

    func saveInProgressWorkout(_ workout: InProgressWorkout) {
        inProgressWorkout = workout
        if let encoded = try? JSONEncoder().encode(workout) {
            UserDefaults.standard.set(encoded, forKey: inProgressKey)
        }
    }

    func clearInProgressWorkout() {
        inProgressWorkout = nil
        UserDefaults.standard.removeObject(forKey: inProgressKey)
    }

    // Update the workout plan with previous weights from completed session
    private func updatePreviousWeights(from session: SessionRecord) {
        guard let planIndex = plans.firstIndex(where: { $0.id == session.planId }) else { return }

        for (exerciseIndex, sessionExercise) in session.exercises.enumerated() {
            // Find the max weight used in completed sets
            let completedSets = sessionExercise.sets.filter { $0.completed }
            if let maxWeight = completedSets.map({ $0.weight }).max(), maxWeight > 0 {
                if exerciseIndex < plans[planIndex].exercises.count {
                    plans[planIndex].exercises[exerciseIndex].previousWeight = maxWeight
                }
            }
        }

        savePlans()
    }

    func getPreviousWeight(for exerciseName: String) -> Double? {
        for session in history {
            if let exercise = session.exercises.first(where: { $0.name == exerciseName }) {
                if let lastSet = exercise.sets.first(where: { $0.completed }) {
                    return lastSet.weight
                }
            }
        }
        return nil
    }

    func getExerciseHistory(for exerciseName: String) -> [(date: Date, weight: Double)] {
        var results: [(Date, Double)] = []

        for session in history.reversed() {
            if let exercise = session.exercises.first(where: { $0.name == exerciseName }) {
                if let maxWeight = exercise.sets.filter(\.completed).map(\.weight).max() {
                    results.append((session.date, maxWeight))
                }
            }
        }

        return results
    }
}
