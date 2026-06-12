import Foundation

// MARK: - User Profile

/// Set once in 30 seconds at onboarding; the coach handles the rest.
struct UserProfile: Codable, Equatable {
    enum Goal: String, Codable, CaseIterable, Identifiable {
        case loseWeight, buildMuscle, getStronger, stayHealthy
        var id: String { rawValue }
        var title: String {
            switch self {
            case .loseWeight: return "Lose Weight"
            case .buildMuscle: return "Build Muscle"
            case .getStronger: return "Get Stronger"
            case .stayHealthy: return "Stay Healthy"
            }
        }
        var icon: String {
            switch self {
            case .loseWeight: return "arrow.down.heart.fill"
            case .buildMuscle: return "figure.arms.open"
            case .getStronger: return "dumbbell.fill"
            case .stayHealthy: return "heart.fill"
            }
        }
    }

    enum Experience: String, Codable, CaseIterable, Identifiable {
        case beginner, intermediate, advanced
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    enum Equipment: String, Codable, CaseIterable, Identifiable {
        case fullGym, homeBasic, bodyweight
        var id: String { rawValue }
        var title: String {
            switch self {
            case .fullGym: return "Full Gym"
            case .homeBasic: return "Home (dumbbells/bands)"
            case .bodyweight: return "Bodyweight Only"
            }
        }
    }

    var goal: Goal = .stayHealthy
    var experience: Experience = .beginner
    var daysPerWeek: Int = 3
    var equipment: Equipment = .fullGym
}

// MARK: - Coach Conversation

struct CoachMessage: Identifiable, Codable, Equatable {
    enum Role: String, Codable {
        case user, coach
    }

    let id: UUID
    var role: Role
    var text: String
    var date: Date
    var actions: [String]

    init(id: UUID = UUID(), role: Role, text: String, date: Date = Date(), actions: [String] = []) {
        self.id = id
        self.role = role
        self.text = text
        self.date = date
        self.actions = actions
    }
}

/// The coach's "one thing today", generated once per day.
struct CoachBrief: Codable, Equatable {
    var date: Date
    var text: String
}
