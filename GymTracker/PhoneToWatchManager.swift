import Foundation
import WatchConnectivity
import Combine

/// Syncs the active workout with the Apple Watch app. The wire format
/// (WatchWorkoutData) is unchanged from the original app, so the watch
/// app works as-is.
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

    // MARK: - Outgoing

    func sendWorkoutToWatch(_ workout: ActiveWorkout) {
        guard let session = session else { return }

        do {
            let data = try JSONEncoder().encode(watchData(for: workout))
            let message: [String: Any] = [
                "action": "startWorkout",
                "workout": data
            ]

            if session.isReachable {
                session.sendMessage(message, replyHandler: nil) { error in
                    print("Error sending workout to watch: \(error)")
                }
            }

            // applicationContext as backup so the watch picks it up on launch
            try session.updateApplicationContext(message)
        } catch {
            print("Failed to send workout: \(error)")
        }
    }

    func updateWorkoutOnWatch(_ workout: ActiveWorkout) {
        guard let session = session, session.isReachable else { return }

        do {
            let data = try JSONEncoder().encode(watchData(for: workout))
            let message: [String: Any] = [
                "action": "updateWorkout",
                "workout": data
            ]
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } catch {
            print("Failed to encode workout update: \(error)")
        }
    }

    func endWorkoutOnWatch() {
        guard let session = session else { return }

        let message: [String: Any] = ["action": "endWorkout"]

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        }

        // Always update application context so the watch won't load a
        // stale workout on next launch.
        do {
            try session.updateApplicationContext(message)
        } catch {
            print("Failed to clear workout context: \(error)")
        }
    }

    func sendTimerToWatch(seconds: Int) {
        guard let session = session, session.isReachable else { return }
        session.sendMessage(["action": "startTimer", "seconds": seconds], replyHandler: nil, errorHandler: nil)
    }

    func sendTimerStopToWatch() {
        guard let session = session, session.isReachable else { return }
        session.sendMessage(["action": "stopTimer"], replyHandler: nil, errorHandler: nil)
    }

    // MARK: - Mapping

    private func watchData(for workout: ActiveWorkout) -> WatchWorkoutData {
        let exercises = workout.exercises.map { exercise -> WatchExerciseData in
            let logged = exercise.sets.filter(\.completed).map { set in
                WatchSetEntryData(id: set.id.uuidString, weight: set.weight, reps: set.reps)
            }
            let referenceWeight = exercise.sets.last(where: \.completed)?.weight
                ?? exercise.sets.first?.weight
                ?? 0

            return WatchExerciseData(
                id: exercise.id.uuidString,
                name: exercise.name,
                targetSets: exercise.sets.count,
                targetReps: exercise.sets.first.map { String($0.reps) } ?? "",
                tempo: nil,
                completedSets: logged.count,
                lastWeight: referenceWeight > 0 ? referenceWeight : nil,
                quickWeights: quickWeights(around: referenceWeight),
                loggedSets: logged
            )
        }

        return WatchWorkoutData(
            id: workout.id.uuidString,
            name: workout.name,
            exercises: exercises
        )
    }

    private func quickWeights(around weight: Double) -> [Double] {
        if weight <= 0 {
            return [45, 65, 95]
        }
        return [max(0, weight - 10), weight, weight + 10]
    }
}

// MARK: - Wire Format (must match the watch app)

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

// MARK: - Incoming

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
                        userInfo: ["exerciseIndex": exerciseIndex, "weight": weight, "reps": reps]
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
                        userInfo: ["exerciseIndex": exerciseIndex, "setIndex": setIndex, "weight": weight, "reps": reps]
                    )
                }

            case "deleteSet":
                if let exerciseIndex = message["exerciseIndex"] as? Int,
                   let setIndex = message["setIndex"] as? Int {
                    NotificationCenter.default.post(
                        name: .watchDidDeleteSet,
                        object: nil,
                        userInfo: ["exerciseIndex": exerciseIndex, "setIndex": setIndex]
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
                NotificationCenter.default.post(name: .watchDidStopTimer, object: nil)

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
