import Foundation
import WatchConnectivity
import Combine

class PhoneToWatchManager: NSObject, ObservableObject {
    static let shared = PhoneToWatchManager()

    private var session: WCSession?

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    // Send workout to watch when starting
    func sendWorkoutToWatch(plan: WorkoutPlan) {
        guard let session = session else {
            print("WCSession not available")
            return
        }

        print("Sending workout to watch - isPaired: \(session.isPaired), isReachable: \(session.isReachable), isWatchAppInstalled: \(session.isWatchAppInstalled)")

        // Convert to watch-friendly format
        let watchExercises = plan.exercises.map { exercise in
            let completedSetEntries = exercise.sets.filter(\.completed).map { set in
                WatchSetEntryData(id: set.id.uuidString, weight: set.weight, reps: set.reps)
            }
            return WatchExerciseData(
                id: exercise.id.uuidString,
                name: exercise.name,
                targetSets: exercise.targetSets,
                targetReps: exercise.targetReps,
                tempo: exercise.tempo,
                completedSets: completedSetEntries.count,
                lastWeight: exercise.previousWeight,
                quickWeights: generateQuickWeights(for: exercise),
                loggedSets: completedSetEntries
            )
        }

        let watchWorkout = WatchWorkoutData(
            id: plan.id.uuidString,
            name: plan.name,
            exercises: watchExercises
        )

        do {
            let data = try JSONEncoder().encode(watchWorkout)
            let message: [String: Any] = [
                "action": "startWorkout",
                "workout": data
            ]

            // Try both methods for simulator compatibility
            if session.isReachable {
                print("Sending via sendMessage")
                session.sendMessage(message, replyHandler: nil) { error in
                    print("Error sending workout to watch: \(error)")
                }
            }

            // Always try applicationContext as backup
            print("Sending via applicationContext")
            try session.updateApplicationContext(message)
        } catch {
            print("Failed to send workout: \(error)")
        }
    }

    // Update workout state on watch
    func updateWorkoutOnWatch(plan: WorkoutPlan) {
        guard let session = session, session.isPaired, session.isWatchAppInstalled else { return }

        let watchExercises = plan.exercises.map { exercise in
            let completedSetEntries = exercise.sets.filter(\.completed).map { set in
                WatchSetEntryData(id: set.id.uuidString, weight: set.weight, reps: set.reps)
            }
            return WatchExerciseData(
                id: exercise.id.uuidString,
                name: exercise.name,
                targetSets: exercise.targetSets,
                targetReps: exercise.targetReps,
                tempo: exercise.tempo,
                completedSets: completedSetEntries.count,
                lastWeight: exercise.sets.last(where: { $0.completed })?.weight ?? exercise.previousWeight,
                quickWeights: generateQuickWeights(for: exercise),
                loggedSets: completedSetEntries
            )
        }

        let watchWorkout = WatchWorkoutData(
            id: plan.id.uuidString,
            name: plan.name,
            exercises: watchExercises
        )

        do {
            let data = try JSONEncoder().encode(watchWorkout)
            let message: [String: Any] = [
                "action": "updateWorkout",
                "workout": data
            ]

            if session.isReachable {
                session.sendMessage(message, replyHandler: nil, errorHandler: nil)
            }
        } catch {
            print("Failed to encode workout update: \(error)")
        }
    }

    // Send current exercise index to watch
    func sendExerciseIndexToWatch(_ index: Int) {
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = [
            "action": "changeExercise",
            "exerciseIndex": index
        ]
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    // End workout on watch
    func endWorkoutOnWatch() {
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = ["action": "endWorkout"]
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    // Send timer start to watch
    func sendTimerToWatch(seconds: Int) {
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = [
            "action": "startTimer",
            "seconds": seconds
        ]
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    // Send timer stop to watch
    func sendTimerStopToWatch() {
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = ["action": "stopTimer"]
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    private func generateQuickWeights(for exercise: Exercise) -> [Double] {
        let baseWeight = exercise.previousWeight ?? 0
        if baseWeight == 0 {
            return [45, 65, 95] // Default weights
        }
        // Suggest weights around the previous weight
        return [
            max(0, baseWeight - 10),
            baseWeight,
            baseWeight + 10
        ]
    }
}

// Codable structs for watch communication
struct WatchWorkoutData: Codable {
    let id: String
    let name: String
    let exercises: [WatchExerciseData]
}

struct WatchSetEntryData: Codable {
    let id: String
    var weight: Double
    var reps: Int
}

struct WatchExerciseData: Codable {
    let id: String
    let name: String
    let targetSets: Int
    let targetReps: String
    let tempo: String?
    var completedSets: Int
    var lastWeight: Double?
    var quickWeights: [Double]
    var loggedSets: [WatchSetEntryData]
}

extension PhoneToWatchManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    // Receive set completion from watch
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            guard let action = message["action"] as? String else { return }

            switch action {
            case "completeSet":
                if let exerciseIndex = message["exerciseIndex"] as? Int,
                   let weight = message["weight"] as? Double,
                   let reps = message["reps"] as? Int {
                    NotificationCenter.default.post(
                        name: .watchDidCompleteSet,
                        object: nil,
                        userInfo: [
                            "exerciseIndex": exerciseIndex,
                            "weight": weight,
                            "reps": reps
                        ]
                    )
                }

            case "updateSet":
                if let exerciseIndex = message["exerciseIndex"] as? Int,
                   let setIndex = message["setIndex"] as? Int,
                   let weight = message["weight"] as? Double,
                   let reps = message["reps"] as? Int {
                    NotificationCenter.default.post(
                        name: .watchDidUpdateSet,
                        object: nil,
                        userInfo: [
                            "exerciseIndex": exerciseIndex,
                            "setIndex": setIndex,
                            "weight": weight,
                            "reps": reps
                        ]
                    )
                }

            case "deleteSet":
                if let exerciseIndex = message["exerciseIndex"] as? Int,
                   let setIndex = message["setIndex"] as? Int {
                    NotificationCenter.default.post(
                        name: .watchDidDeleteSet,
                        object: nil,
                        userInfo: [
                            "exerciseIndex": exerciseIndex,
                            "setIndex": setIndex
                        ]
                    )
                }

            case "changeExercise":
                if let exerciseIndex = message["exerciseIndex"] as? Int {
                    NotificationCenter.default.post(
                        name: .watchDidChangeExercise,
                        object: nil,
                        userInfo: ["exerciseIndex": exerciseIndex]
                    )
                }

            case "startTimer":
                if let seconds = message["seconds"] as? Int {
                    NotificationCenter.default.post(
                        name: .watchDidStartTimer,
                        object: nil,
                        userInfo: ["seconds": seconds]
                    )
                }

            case "stopTimer":
                NotificationCenter.default.post(
                    name: .watchDidStopTimer,
                    object: nil
                )

            default:
                break
            }
        }
    }
}

extension Notification.Name {
    static let watchDidCompleteSet = Notification.Name("watchDidCompleteSet")
    static let watchDidUpdateSet = Notification.Name("watchDidUpdateSet")
    static let watchDidDeleteSet = Notification.Name("watchDidDeleteSet")
    static let watchDidChangeExercise = Notification.Name("watchDidChangeExercise")
    static let watchDidStartTimer = Notification.Name("watchDidStartTimer")
    static let watchDidStopTimer = Notification.Name("watchDidStopTimer")
}
