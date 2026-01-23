import Foundation
import WatchConnectivity
import Combine

// Simplified models for watch
struct WatchWorkout: Codable {
    let id: String
    let name: String
    var exercises: [WatchExercise]
}

struct WatchSetEntry: Codable, Identifiable {
    let id: UUID
    var weight: Double
    var reps: Int

    init(id: UUID = UUID(), weight: Double, reps: Int) {
        self.id = id
        self.weight = weight
        self.reps = reps
    }

    // Custom decoder to handle String id from phone
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        weight = try container.decode(Double.self, forKey: .weight)
        reps = try container.decode(Int.self, forKey: .reps)

        // Try to decode as UUID first, then as String
        if let uuid = try? container.decode(UUID.self, forKey: .id) {
            id = uuid
        } else if let idString = try? container.decode(String.self, forKey: .id),
                  let uuid = UUID(uuidString: idString) {
            id = uuid
        } else {
            id = UUID()
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, weight, reps
    }
}

struct WatchExercise: Codable, Identifiable {
    let id: String
    let name: String
    let targetSets: Int
    let targetReps: String
    let tempo: String?
    var completedSets: Int
    var lastWeight: Double?
    var quickWeights: [Double]
    var loggedSets: [WatchSetEntry] // Track individual sets

    init(id: String, name: String, targetSets: Int, targetReps: String, tempo: String? = nil, completedSets: Int, lastWeight: Double?, quickWeights: [Double], loggedSets: [WatchSetEntry] = []) {
        self.id = id
        self.name = name
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.tempo = tempo
        self.completedSets = completedSets
        self.lastWeight = lastWeight
        self.quickWeights = quickWeights
        self.loggedSets = loggedSets
    }

    // Custom decoder to handle missing loggedSets and tempo from phone
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        targetSets = try container.decode(Int.self, forKey: .targetSets)
        targetReps = try container.decode(String.self, forKey: .targetReps)
        tempo = try container.decodeIfPresent(String.self, forKey: .tempo)
        completedSets = try container.decode(Int.self, forKey: .completedSets)
        lastWeight = try container.decodeIfPresent(Double.self, forKey: .lastWeight)
        quickWeights = try container.decode([Double].self, forKey: .quickWeights)
        loggedSets = try container.decodeIfPresent([WatchSetEntry].self, forKey: .loggedSets) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case id, name, targetSets, targetReps, tempo, completedSets, lastWeight, quickWeights, loggedSets
    }
}

class WatchWorkoutManager: NSObject, ObservableObject {
    static let shared = WatchWorkoutManager()

    @Published var activeWorkout: WatchWorkout?
    @Published var currentExerciseIndex: Int = 0

    private var session: WCSession?

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func logSet(exerciseIndex: Int, weight: Double, reps: Int) {
        guard var workout = activeWorkout,
              exerciseIndex < workout.exercises.count else { return }

        let newSet = WatchSetEntry(id: UUID(), weight: weight, reps: reps)
        workout.exercises[exerciseIndex].loggedSets.append(newSet)
        workout.exercises[exerciseIndex].completedSets = workout.exercises[exerciseIndex].loggedSets.count
        workout.exercises[exerciseIndex].lastWeight = weight

        activeWorkout = workout

        // Send update to phone
        sendSetCompletion(exerciseIndex: exerciseIndex, weight: weight, reps: reps)
    }

    func updateSet(exerciseIndex: Int, setIndex: Int, weight: Double, reps: Int) {
        guard var workout = activeWorkout,
              exerciseIndex < workout.exercises.count,
              setIndex < workout.exercises[exerciseIndex].loggedSets.count else { return }

        workout.exercises[exerciseIndex].loggedSets[setIndex].weight = weight
        workout.exercises[exerciseIndex].loggedSets[setIndex].reps = reps

        activeWorkout = workout

        // Send update to phone
        sendSetUpdate(exerciseIndex: exerciseIndex, setIndex: setIndex, weight: weight, reps: reps)
    }

    func deleteSet(exerciseIndex: Int, setIndex: Int) {
        guard var workout = activeWorkout,
              exerciseIndex < workout.exercises.count,
              setIndex < workout.exercises[exerciseIndex].loggedSets.count else { return }

        workout.exercises[exerciseIndex].loggedSets.remove(at: setIndex)
        workout.exercises[exerciseIndex].completedSets = workout.exercises[exerciseIndex].loggedSets.count

        activeWorkout = workout

        // Send update to phone
        sendSetDelete(exerciseIndex: exerciseIndex, setIndex: setIndex)
    }

    private func sendSetCompletion(exerciseIndex: Int, weight: Double, reps: Int) {
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = [
            "action": "completeSet",
            "exerciseIndex": exerciseIndex,
            "weight": weight,
            "reps": reps
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            print("Error sending set completion: \(error)")
        }
    }

    private func sendSetUpdate(exerciseIndex: Int, setIndex: Int, weight: Double, reps: Int) {
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = [
            "action": "updateSet",
            "exerciseIndex": exerciseIndex,
            "setIndex": setIndex,
            "weight": weight,
            "reps": reps
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            print("Error sending set update: \(error)")
        }
    }

    private func sendSetDelete(exerciseIndex: Int, setIndex: Int) {
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = [
            "action": "deleteSet",
            "exerciseIndex": exerciseIndex,
            "setIndex": setIndex
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            print("Error sending set delete: \(error)")
        }
    }

    func sendExerciseIndexToPhone(_ index: Int) {
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = [
            "action": "changeExercise",
            "exerciseIndex": index
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            print("Error sending exercise index: \(error)")
        }
    }
}

extension WatchWorkoutManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error)")
        } else {
            print("WCSession activated successfully")
            // Check for existing application context
            DispatchQueue.main.async {
                let context = session.receivedApplicationContext
                if !context.isEmpty {
                    print("Found existing application context")
                    self.handleMessage(context)
                }
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("Received message from phone")
        DispatchQueue.main.async {
            self.handleMessage(message)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        print("Received application context from phone")
        DispatchQueue.main.async {
            self.handleMessage(applicationContext)
        }
    }

    private func handleMessage(_ message: [String: Any]) {
        if let action = message["action"] as? String {
            switch action {
            case "startWorkout":
                if let workoutData = message["workout"] as? Data {
                    do {
                        let workout = try JSONDecoder().decode(WatchWorkout.self, from: workoutData)
                        activeWorkout = workout
                    } catch {
                        print("Failed to decode workout: \(error)")
                    }
                }
            case "updateWorkout":
                if let workoutData = message["workout"] as? Data {
                    do {
                        let incomingWorkout = try JSONDecoder().decode(WatchWorkout.self, from: workoutData)

                        // Merge with existing data to preserve loggedSets
                        if var currentWorkout = activeWorkout, currentWorkout.id == incomingWorkout.id {
                            for (index, incomingExercise) in incomingWorkout.exercises.enumerated() {
                                if index < currentWorkout.exercises.count {
                                    let localLoggedSets = currentWorkout.exercises[index].loggedSets
                                    let incomingLoggedSets = incomingExercise.loggedSets

                                    // Use whichever has more sets (phone or watch)
                                    if incomingLoggedSets.count > localLoggedSets.count {
                                        // Phone has more sets - use phone's data
                                        currentWorkout.exercises[index].loggedSets = incomingLoggedSets
                                        currentWorkout.exercises[index].completedSets = incomingLoggedSets.count
                                        currentWorkout.exercises[index].lastWeight = incomingExercise.lastWeight
                                    } else if localLoggedSets.count > incomingLoggedSets.count {
                                        // Watch has more sets - keep local data
                                        currentWorkout.exercises[index].completedSets = localLoggedSets.count
                                    } else {
                                        // Same count - prefer phone's data for consistency
                                        currentWorkout.exercises[index].loggedSets = incomingLoggedSets
                                        currentWorkout.exercises[index].completedSets = incomingLoggedSets.count
                                        currentWorkout.exercises[index].lastWeight = incomingExercise.lastWeight
                                    }
                                }
                            }
                            activeWorkout = currentWorkout
                        } else {
                            // Different workout, just replace
                            activeWorkout = incomingWorkout
                        }
                    } catch {
                        print("Failed to decode workout update: \(error)")
                    }
                }
            case "changeExercise":
                if let exerciseIndex = message["exerciseIndex"] as? Int {
                    currentExerciseIndex = exerciseIndex
                }
            case "endWorkout":
                activeWorkout = nil
                currentExerciseIndex = 0
            default:
                break
            }
        }
    }
}
