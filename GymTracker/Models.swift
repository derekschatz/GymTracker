import Foundation
import SwiftUI

// MARK: - Core Data Models

struct WorkoutPlan: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var exercises: [Exercise]

    init(id: UUID = UUID(), name: String, exercises: [Exercise]) {
        self.id = id
        self.name = name
        self.exercises = exercises
    }
}

struct Exercise: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var targetSets: Int
    var targetReps: String
    var tempo: String?
    var notes: String?
    var previousWeight: Double?
    var sets: [SetEntry]
    var supersetId: String?

    init(id: UUID = UUID(), name: String, targetSets: Int = 0, targetReps: String = "", tempo: String? = nil, notes: String? = nil, previousWeight: Double? = nil, sets: [SetEntry] = [], supersetId: String? = nil) {
        self.id = id
        self.name = name
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.tempo = tempo
        self.notes = notes
        self.previousWeight = previousWeight
        self.sets = sets
        self.supersetId = supersetId
    }

    // Custom decoder to handle old data that may have extra fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        targetSets = try container.decodeIfPresent(Int.self, forKey: .targetSets) ?? 0
        targetReps = try container.decodeIfPresent(String.self, forKey: .targetReps) ?? ""
        tempo = try container.decodeIfPresent(String.self, forKey: .tempo)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        previousWeight = try container.decodeIfPresent(Double.self, forKey: .previousWeight)
        sets = try container.decodeIfPresent([SetEntry].self, forKey: .sets) ?? []
        supersetId = try container.decodeIfPresent(String.self, forKey: .supersetId)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, targetSets, targetReps, tempo, notes, previousWeight, sets, supersetId
    }
}

struct SetEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var weight: Double
    var reps: Int
    var completed: Bool
    var timestamp: Date?

    init(id: UUID = UUID(), weight: Double, reps: Int, completed: Bool, timestamp: Date? = nil) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.completed = completed
        self.timestamp = timestamp
    }
}

struct SessionRecord: Identifiable, Codable {
    let id: UUID
    let planId: UUID
    var planName: String
    var date: Date
    var exercises: [Exercise]
    var totalVolume: Double
    var heartRate: Double?
    var calories: Double?
    var duration: TimeInterval?

    init(id: UUID = UUID(), planId: UUID, planName: String, date: Date, exercises: [Exercise], totalVolume: Double, heartRate: Double? = nil, calories: Double? = nil, duration: TimeInterval? = nil) {
        self.id = id
        self.planId = planId
        self.planName = planName
        self.date = date
        self.exercises = exercises
        self.totalVolume = totalVolume
        self.heartRate = heartRate
        self.calories = calories
        self.duration = duration
    }
}

// MARK: - Helper Extensions

extension Exercise {
    func createDefaultSets() -> [SetEntry] {
        // Check if reps are comma-separated (e.g., "10, 10, 8, 6")
        let commaSeparated = targetReps.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        if commaSeparated.count > 1 {
            // Use comma-separated values for each set
            return (0..<targetSets).map { index in
                let repString = index < commaSeparated.count ? commaSeparated[index] : commaSeparated.last ?? "0"
                // Handle if individual rep is a range like "8-10" - use first number
                let reps = Int(repString.components(separatedBy: "-").first ?? "0") ?? 0
                return SetEntry(weight: previousWeight ?? 0, reps: reps, completed: false)
            }
        } else {
            // Single value or range (e.g., "10" or "8-10") - use same for all sets
            let defaultReps = Int(targetReps.components(separatedBy: "-").first ?? "0") ?? 0
            return (0..<targetSets).map { _ in
                SetEntry(weight: previousWeight ?? 0, reps: defaultReps, completed: false)
            }
        }
    }
}

extension SessionRecord {
    static func calculateTotalVolume(exercises: [Exercise]) -> Double {
        exercises.reduce(0.0) { total, exercise in
            total + exercise.sets.filter(\.completed).reduce(0.0) { setTotal, set in
                setTotal + (set.weight * Double(set.reps))
            }
        }
    }
}
