import Foundation

// MARK: - Exercise Library

struct Exercise: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - Workouts

struct WorkoutSet: Identifiable, Codable, Hashable {
    let id: UUID
    var weight: Double
    var reps: Int
    var completed: Bool

    init(id: UUID = UUID(), weight: Double = 0, reps: Int = 10, completed: Bool = false) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.completed = completed
    }
}

struct WorkoutExercise: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var sets: [WorkoutSet]

    init(id: UUID = UUID(), name: String, sets: [WorkoutSet] = []) {
        self.id = id
        self.name = name
        self.sets = sets
    }

    var completedSets: [WorkoutSet] {
        sets.filter(\.completed)
    }

    var volume: Double {
        completedSets.reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    var topWeight: Double? {
        completedSets.map(\.weight).max()
    }
}

/// A finished workout session stored in history.
struct Workout: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var date: Date
    var duration: TimeInterval
    var exercises: [WorkoutExercise]

    init(id: UUID = UUID(), name: String, date: Date, duration: TimeInterval, exercises: [WorkoutExercise]) {
        self.id = id
        self.name = name
        self.date = date
        self.duration = duration
        self.exercises = exercises
    }

    var totalVolume: Double {
        exercises.reduce(0) { $0 + $1.volume }
    }

    var completedSetCount: Int {
        exercises.reduce(0) { $0 + $1.completedSets.count }
    }
}

/// The workout currently in progress. Persisted so a crash or app
/// termination never loses a session.
struct ActiveWorkout: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var startDate: Date
    var exercises: [WorkoutExercise]

    init(id: UUID = UUID(), name: String, startDate: Date = Date(), exercises: [WorkoutExercise] = []) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.exercises = exercises
    }
}

// MARK: - Routines

struct RoutineExercise: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var setCount: Int
    var reps: Int

    init(id: UUID = UUID(), name: String, setCount: Int = 3, reps: Int = 10) {
        self.id = id
        self.name = name
        self.setCount = setCount
        self.reps = reps
    }
}

struct Routine: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var exercises: [RoutineExercise]

    init(id: UUID = UUID(), name: String, exercises: [RoutineExercise] = []) {
        self.id = id
        self.name = name
        self.exercises = exercises
    }
}

// MARK: - Nutrition

enum Meal: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snacks

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.fill"
        case .snacks: return "carrot.fill"
        }
    }
}

struct Food: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var serving: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    init(id: UUID = UUID(), name: String, serving: String = "1 serving",
         calories: Double = 0, protein: Double = 0, carbs: Double = 0, fat: Double = 0) {
        self.id = id
        self.name = name
        self.serving = serving
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }
}

/// A logged food. Stores a snapshot of the food so editing the library
/// never rewrites past days.
struct FoodEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var date: Date
    var meal: Meal
    var food: Food
    var servings: Double

    init(id: UUID = UUID(), date: Date = Date(), meal: Meal, food: Food, servings: Double = 1) {
        self.id = id
        self.date = date
        self.meal = meal
        self.food = food
        self.servings = servings
    }

    var calories: Double { food.calories * servings }
    var protein: Double { food.protein * servings }
    var carbs: Double { food.carbs * servings }
    var fat: Double { food.fat * servings }
}

struct NutritionTotals {
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
}

// MARK: - Body Weight & Goals

struct WeightEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var date: Date
    var weight: Double

    init(id: UUID = UUID(), date: Date = Date(), weight: Double) {
        self.id = id
        self.date = date
        self.weight = weight
    }
}

struct Goals: Codable, Equatable {
    var calories: Double = 2000
    var protein: Double = 150
}

// MARK: - Cardio

enum CardioActivity: String, Codable, CaseIterable, Identifiable {
    case run, walk, cycle, swim, row, elliptical, stairs, hike, sport, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .run: return "Run"
        case .walk: return "Walk"
        case .cycle: return "Cycle"
        case .swim: return "Swim"
        case .row: return "Row"
        case .elliptical: return "Elliptical"
        case .stairs: return "Stairs"
        case .hike: return "Hike"
        case .sport: return "Sport"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .run: return "figure.run"
        case .walk: return "figure.walk"
        case .cycle: return "figure.outdoor.cycle"
        case .swim: return "figure.pool.swim"
        case .row: return "figure.rower"
        case .elliptical: return "figure.elliptical"
        case .stairs: return "figure.stair.stepper"
        case .hike: return "figure.hiking"
        case .sport: return "sportscourt.fill"
        case .other: return "heart.fill"
        }
    }

    var supportsDistance: Bool {
        switch self {
        case .run, .walk, .cycle, .swim, .row, .hike: return true
        default: return false
        }
    }
}

struct CardioEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var activity: CardioActivity
    var date: Date
    var duration: TimeInterval
    var distance: Double? // miles

    init(id: UUID = UUID(), activity: CardioActivity, date: Date = Date(),
         duration: TimeInterval, distance: Double? = nil) {
        self.id = id
        self.activity = activity
        self.date = date
        self.duration = duration
        self.distance = distance
    }

    var summary: String {
        var parts = [duration.shortDuration]
        if let distance, distance > 0 {
            parts.append("\(distance.clean) mi")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Formatting Helpers

extension Double {
    /// "185" or "187.5" — no trailing ".0" noise.
    var clean: String {
        if truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", self)
        }
        return String(format: "%.1f", self)
    }
}

extension TimeInterval {
    var shortDuration: String {
        let minutes = Int(self) / 60
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}
