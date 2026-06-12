import Foundation
import Combine

/// Single source of truth for the whole app. Everything is plain Codable
/// data saved as JSON files with atomic writes — simple and reliable.
@MainActor
final class AppStore: ObservableObject {
    static let shared = AppStore()

    @Published private(set) var workouts: [Workout] = []          // newest first
    @Published private(set) var cardioEntries: [CardioEntry] = [] // newest first
    @Published private(set) var routines: [Routine] = []
    @Published private(set) var exercises: [Exercise] = []
    @Published private(set) var foods: [Food] = []
    @Published private(set) var foodEntries: [FoodEntry] = []
    @Published private(set) var weightEntries: [WeightEntry] = [] // newest first

    @Published var goals = Goals() {
        didSet { if !isLoading { save(goals, as: FileName.goals) } }
    }

    @Published var activeWorkout: ActiveWorkout? {
        didSet {
            guard !isLoading else { return }
            if let activeWorkout {
                save(activeWorkout, as: FileName.activeWorkout)
                scheduleWatchSync()
            } else {
                pendingWatchSync?.cancel()
                removeFile(FileName.activeWorkout)
            }
        }
    }

    /// Drives the full-screen workout cover from any tab.
    @Published var isWorkoutPresented = false

    /// Root tab selection, so any screen can deep-link to another tab.
    @Published var selectedTab = 0

    // MARK: Coach state

    @Published var profile: UserProfile? {
        didSet {
            guard !isLoading else { return }
            if let profile {
                save(profile, as: FileName.profile)
            } else {
                removeFile(FileName.profile)
            }
        }
    }

    @Published private(set) var coachMessages: [CoachMessage] = []

    @Published var dailyBrief: CoachBrief? {
        didSet {
            guard !isLoading else { return }
            if let dailyBrief {
                save(dailyBrief, as: FileName.dailyBrief)
            } else {
                removeFile(FileName.dailyBrief)
            }
        }
    }

    private var isLoading = false
    private var cancellables = Set<AnyCancellable>()
    private var pendingWatchSync: DispatchWorkItem?

    private enum FileName {
        static let workouts = "workouts.json"
        static let routines = "routines.json"
        static let exercises = "exercises.json"
        static let foods = "foods.json"
        static let foodEntries = "food-entries.json"
        static let weightEntries = "weight-entries.json"
        static let goals = "goals.json"
        static let activeWorkout = "active-workout.json"
        static let profile = "profile.json"
        static let coachMessages = "coach-messages.json"
        static let dailyBrief = "daily-brief.json"
        static let cardio = "cardio.json"
    }

    private init() {
        isLoading = true
        workouts = load([Workout].self, from: FileName.workouts) ?? []
        routines = load([Routine].self, from: FileName.routines) ?? []
        exercises = load([Exercise].self, from: FileName.exercises) ?? []
        foods = load([Food].self, from: FileName.foods) ?? []
        foodEntries = load([FoodEntry].self, from: FileName.foodEntries) ?? []
        weightEntries = load([WeightEntry].self, from: FileName.weightEntries) ?? []
        goals = load(Goals.self, from: FileName.goals) ?? Goals()
        activeWorkout = load(ActiveWorkout.self, from: FileName.activeWorkout)
        profile = load(UserProfile.self, from: FileName.profile)
        coachMessages = load([CoachMessage].self, from: FileName.coachMessages) ?? []
        dailyBrief = load(CoachBrief.self, from: FileName.dailyBrief)
        cardioEntries = load([CardioEntry].self, from: FileName.cardio) ?? []

        migrateLegacyDataIfNeeded()
        seedExercisesIfNeeded()
        isLoading = false

        observeWatchEvents()
    }

    // MARK: - Workouts

    func startWorkout(name: String, exercises: [WorkoutExercise] = []) {
        let workout = ActiveWorkout(name: name, exercises: exercises)
        activeWorkout = workout
        PhoneToWatchManager.shared.sendWorkoutToWatch(workout)
        isWorkoutPresented = true
    }

    func startWorkout(from routine: Routine) {
        let exercises = routine.exercises.map { item -> WorkoutExercise in
            let lastWeight = lastSets(for: item.name)?.map(\.weight).max() ?? 0
            let sets = (0..<max(item.setCount, 1)).map { _ in
                WorkoutSet(weight: lastWeight, reps: item.reps)
            }
            return WorkoutExercise(name: item.name, sets: sets)
        }
        startWorkout(name: routine.name, exercises: exercises)
    }

    /// Builds an exercise for the active workout, prefilled from the most
    /// recent time it was performed.
    func newWorkoutExercise(named name: String) -> WorkoutExercise {
        if let last = lastSets(for: name), !last.isEmpty {
            return WorkoutExercise(name: name, sets: last.map { WorkoutSet(weight: $0.weight, reps: $0.reps) })
        }
        return WorkoutExercise(name: name, sets: [WorkoutSet(), WorkoutSet(), WorkoutSet()])
    }

    /// Saves the active workout to history. Returns nil (and discards) if
    /// nothing was actually completed.
    @discardableResult
    func finishActiveWorkout() -> Workout? {
        guard let active = activeWorkout else { return nil }

        let finishedExercises = active.exercises
            .map { WorkoutExercise(id: $0.id, name: $0.name, sets: $0.completedSets) }
            .filter { !$0.sets.isEmpty }

        activeWorkout = nil
        PhoneToWatchManager.shared.endWorkoutOnWatch()

        guard !finishedExercises.isEmpty else { return nil }

        let workout = Workout(
            name: active.name,
            date: active.startDate,
            duration: Date().timeIntervalSince(active.startDate),
            exercises: finishedExercises
        )
        workouts.insert(workout, at: 0)
        save(workouts, as: FileName.workouts)
        return workout
    }

    func cancelActiveWorkout() {
        activeWorkout = nil
        PhoneToWatchManager.shared.endWorkoutOnWatch()
    }

    func deleteWorkout(_ workout: Workout) {
        workouts.removeAll { $0.id == workout.id }
        save(workouts, as: FileName.workouts)
    }

    func workouts(on date: Date) -> [Workout] {
        workouts.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    /// The sets logged the last time this exercise was performed.
    func lastSets(for exerciseName: String) -> [WorkoutSet]? {
        for workout in workouts {
            if let match = workout.exercises.first(where: { $0.name.caseInsensitiveCompare(exerciseName) == .orderedSame }) {
                let completed = match.completedSets
                if !completed.isEmpty { return completed }
            }
        }
        return nil
    }

    /// Top completed weight per session for an exercise, oldest first.
    func progress(for exerciseName: String) -> [(date: Date, weight: Double)] {
        var points: [(Date, Double)] = []
        for workout in workouts.reversed() {
            if let match = workout.exercises.first(where: { $0.name.caseInsensitiveCompare(exerciseName) == .orderedSame }),
               let top = match.topWeight {
                points.append((workout.date, top))
            }
        }
        return points
    }

    // MARK: - Cardio

    func logCardio(_ entry: CardioEntry) {
        cardioEntries.insert(entry, at: 0)
        cardioEntries.sort { $0.date > $1.date }
        save(cardioEntries, as: FileName.cardio)
    }

    func deleteCardio(_ entry: CardioEntry) {
        cardioEntries.removeAll { $0.id == entry.id }
        save(cardioEntries, as: FileName.cardio)
    }

    func cardioEntries(on date: Date) -> [CardioEntry] {
        cardioEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    // MARK: - Routines

    func addRoutine(_ routine: Routine) {
        routines.append(routine)
        save(routines, as: FileName.routines)
    }

    func updateRoutine(_ routine: Routine) {
        guard let index = routines.firstIndex(where: { $0.id == routine.id }) else { return }
        routines[index] = routine
        save(routines, as: FileName.routines)
    }

    func deleteRoutine(_ routine: Routine) {
        routines.removeAll { $0.id == routine.id }
        save(routines, as: FileName.routines)
    }

    func saveAsRoutine(_ workout: Workout) {
        let items = workout.exercises.map { exercise in
            RoutineExercise(
                name: exercise.name,
                setCount: max(exercise.sets.count, 1),
                reps: exercise.sets.first?.reps ?? 10
            )
        }
        addRoutine(Routine(name: workout.name, exercises: items))
    }

    // MARK: - Exercise Library

    /// Adds (or finds) an exercise by name. Case-insensitive de-dupe.
    @discardableResult
    func addExercise(named name: String) -> Exercise {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = exercises.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return existing
        }
        let exercise = Exercise(name: trimmed)
        exercises.append(exercise)
        exercises.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        save(exercises, as: FileName.exercises)
        return exercise
    }

    func deleteExercise(_ exercise: Exercise) {
        exercises.removeAll { $0.id == exercise.id }
        save(exercises, as: FileName.exercises)
    }

    // MARK: - Foods

    func addFood(_ food: Food) {
        foods.append(food)
        foods.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        save(foods, as: FileName.foods)
    }

    func updateFood(_ food: Food) {
        guard let index = foods.firstIndex(where: { $0.id == food.id }) else { return }
        foods[index] = food
        save(foods, as: FileName.foods)
    }

    func deleteFood(_ food: Food) {
        foods.removeAll { $0.id == food.id }
        save(foods, as: FileName.foods)
    }

    /// Foods logged most recently, for one-tap re-logging.
    func recentFoods(limit: Int = 8) -> [Food] {
        var seen = Set<UUID>()
        var result: [Food] = []
        for entry in foodEntries.sorted(by: { $0.date > $1.date }) {
            if seen.insert(entry.food.id).inserted {
                result.append(entry.food)
                if result.count >= limit { break }
            }
        }
        return result
    }

    // MARK: - Food Log

    func logFood(_ food: Food, servings: Double, meal: Meal, date: Date) {
        let entry = FoodEntry(date: date, meal: meal, food: food, servings: servings)
        foodEntries.append(entry)
        save(foodEntries, as: FileName.foodEntries)
    }

    func updateFoodEntry(_ entry: FoodEntry) {
        guard let index = foodEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        foodEntries[index] = entry
        save(foodEntries, as: FileName.foodEntries)
    }

    func deleteFoodEntry(_ entry: FoodEntry) {
        foodEntries.removeAll { $0.id == entry.id }
        save(foodEntries, as: FileName.foodEntries)
    }

    /// Re-logs a whole meal from another day — for the "same breakfast
    /// every day" reality.
    func copyMeal(_ meal: Meal, from sourceDate: Date, to targetDate: Date) {
        let source = foodEntries(on: sourceDate, meal: meal)
        guard !source.isEmpty else { return }
        for entry in source {
            foodEntries.append(
                FoodEntry(date: targetDate, meal: meal, food: entry.food, servings: entry.servings)
            )
        }
        save(foodEntries, as: FileName.foodEntries)
    }

    func foodEntries(on date: Date, meal: Meal) -> [FoodEntry] {
        foodEntries
            .filter { $0.meal == meal && Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }

    func nutritionTotals(on date: Date) -> NutritionTotals {
        var totals = NutritionTotals()
        for entry in foodEntries where Calendar.current.isDate(entry.date, inSameDayAs: date) {
            totals.calories += entry.calories
            totals.protein += entry.protein
            totals.carbs += entry.carbs
            totals.fat += entry.fat
        }
        return totals
    }

    // MARK: - Body Weight

    func logWeight(_ weight: Double, date: Date = Date()) {
        weightEntries.insert(WeightEntry(date: date, weight: weight), at: 0)
        weightEntries.sort { $0.date > $1.date }
        save(weightEntries, as: FileName.weightEntries)
    }

    func deleteWeightEntry(_ entry: WeightEntry) {
        weightEntries.removeAll { $0.id == entry.id }
        save(weightEntries, as: FileName.weightEntries)
    }

    var latestWeight: WeightEntry? {
        weightEntries.first
    }

    // MARK: - Coach

    func appendCoachMessage(_ message: CoachMessage) {
        coachMessages.append(message)
        // Keep the conversation bounded; old turns matter less than fresh data.
        if coachMessages.count > 60 {
            coachMessages.removeFirst(coachMessages.count - 60)
        }
        save(coachMessages, as: FileName.coachMessages)
    }

    func clearCoachConversation() {
        coachMessages = []
        removeFile(FileName.coachMessages)
    }

    var hasBriefForToday: Bool {
        guard let dailyBrief else { return false }
        return Calendar.current.isDateInToday(dailyBrief.date)
    }

    /// Everything the coach can see, as a compact text packet.
    func coachContext() -> String {
        var lines: [String] = ["CONTEXT — the user's real data as of \(Date().formatted(.dateTime.weekday(.wide).month().day())):"]

        if let profile {
            lines.append("PROFILE: goal=\(profile.goal.title), experience=\(profile.experience.title), wants to train \(profile.daysPerWeek) days/week, equipment=\(profile.equipment.title)")
        } else {
            lines.append("PROFILE: not set up yet")
        }

        lines.append("DAILY TARGETS: \(goals.calories.clean) cal, \(goals.protein.clean)g protein")

        // Today's nutrition
        let today = nutritionTotals(on: Date())
        lines.append("TODAY SO FAR: \(today.calories.clean) cal eaten (P \(today.protein.clean)g / C \(today.carbs.clean)g / F \(today.fat.clean)g)")

        // 7-day nutrition average over days that have entries
        var loggedDays = 0
        var calorieSum = 0.0
        for offset in 0..<7 {
            if let day = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) {
                let totals = nutritionTotals(on: day)
                if totals.calories > 0 {
                    loggedDays += 1
                    calorieSum += totals.calories
                }
            }
        }
        if loggedDays > 0 {
            lines.append("NUTRITION LAST 7 DAYS: logged \(loggedDays)/7 days, averaging \((calorieSum / Double(loggedDays)).clean) cal on logged days")
        } else {
            lines.append("NUTRITION LAST 7 DAYS: nothing logged")
        }

        // Body weight trend
        if let latest = latestWeight {
            var weightLine = "BODY WEIGHT: \(latest.weight.clean) lb (\(latest.date.formatted(.dateTime.month(.abbreviated).day())))"
            if let monthAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()),
               let old = weightEntries.last(where: { $0.date >= monthAgo }),
               old.id != latest.id {
                let delta = latest.weight - old.weight
                weightLine += ", \(delta >= 0 ? "+" : "")\(delta.clean) lb over ~30 days"
            }
            lines.append(weightLine)
        } else {
            lines.append("BODY WEIGHT: never logged")
        }

        // Training consistency — the signal that matters most for coaching.
        let calendar = Calendar.current
        let week = workouts.filter { $0.date > calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date() }.count
        let month = workouts.filter { $0.date > calendar.date(byAdding: .day, value: -28, to: Date()) ?? Date() }.count
        if let last = workouts.first {
            let daysAgo = calendar.dateComponents([.day], from: last.date, to: Date()).day ?? 0
            lines.append("TRAINING: last workout \(daysAgo == 0 ? "today" : "\(daysAgo) days ago"); \(week) workouts in last 7 days, \(month) in last 28 days")
        } else {
            lines.append("TRAINING: no workouts logged yet")
        }

        // Cardio
        let cardioWeek = cardioEntries.filter { $0.date > calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date() }
        if cardioWeek.isEmpty {
            lines.append("CARDIO LAST 7 DAYS: none logged")
        } else {
            let minutes = Int(cardioWeek.reduce(0) { $0 + $1.duration } / 60)
            let sessions = cardioWeek
                .prefix(4)
                .map { "\($0.activity.title) \($0.summary)" }
                .joined(separator: ", ")
            lines.append("CARDIO LAST 7 DAYS: \(cardioWeek.count) sessions, \(minutes) min total — \(sessions)")
        }

        if activeWorkout != nil {
            lines.append("A WORKOUT IS IN PROGRESS RIGHT NOW.")
        }

        // Recent workouts with their lifts
        for workout in workouts.prefix(3) {
            let exercises = workout.exercises.map { exercise -> String in
                if let top = exercise.topWeight {
                    return "\(exercise.name) \(top.clean)x\(exercise.completedSets.last?.reps ?? 0)"
                }
                return exercise.name
            }
            lines.append("WORKOUT \(workout.date.formatted(.dateTime.month(.abbreviated).day())): \(workout.name) — \(exercises.joined(separator: ", "))")
        }

        // Saved routines
        if routines.isEmpty {
            lines.append("ROUTINES: none saved")
        } else {
            for routine in routines {
                let items = routine.exercises.map { "\($0.name) \($0.setCount)x\($0.reps)" }
                lines.append("ROUTINE '\(routine.name)': \(items.joined(separator: ", "))")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Watch Sync

    /// Pushes the active workout to the watch shortly after it stops
    /// changing, so rapid edits (e.g. typing a weight) don't flood the
    /// watch with stale intermediate snapshots.
    private func scheduleWatchSync() {
        pendingWatchSync?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, let workout = self.activeWorkout else { return }
            PhoneToWatchManager.shared.updateWorkoutOnWatch(workout)
        }
        pendingWatchSync = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    /// Watch events are applied here — not in a view — so sets logged on
    /// the watch are never lost while the workout screen is off-screen.
    private func observeWatchEvents() {
        NotificationCenter.default.publisher(for: .watchDidCompleteSet)
            .sink { [weak self] note in self?.applyWatchCompleteSet(note) }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .watchDidUpdateSet)
            .sink { [weak self] note in self?.applyWatchUpdateSet(note) }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .watchDidDeleteSet)
            .sink { [weak self] note in self?.applyWatchDeleteSet(note) }
            .store(in: &cancellables)
    }

    private func applyWatchCompleteSet(_ note: Notification) {
        guard let exerciseIndex = note.userInfo?["exerciseIndex"] as? Int,
              let weight = note.userInfo?["weight"] as? Double,
              let reps = note.userInfo?["reps"] as? Int,
              var workout = activeWorkout,
              workout.exercises.indices.contains(exerciseIndex)
        else { return }

        if let setIndex = workout.exercises[exerciseIndex].sets.firstIndex(where: { !$0.completed }) {
            workout.exercises[exerciseIndex].sets[setIndex].weight = weight
            workout.exercises[exerciseIndex].sets[setIndex].reps = reps
            workout.exercises[exerciseIndex].sets[setIndex].completed = true
        } else {
            workout.exercises[exerciseIndex].sets.append(WorkoutSet(weight: weight, reps: reps, completed: true))
        }
        activeWorkout = workout
    }

    private func applyWatchUpdateSet(_ note: Notification) {
        guard let exerciseIndex = note.userInfo?["exerciseIndex"] as? Int,
              let setIndex = note.userInfo?["setIndex"] as? Int,
              let weight = note.userInfo?["weight"] as? Double,
              let reps = note.userInfo?["reps"] as? Int,
              var workout = activeWorkout,
              workout.exercises.indices.contains(exerciseIndex)
        else { return }

        // The watch indexes into completed sets only.
        let completedIndices = workout.exercises[exerciseIndex].sets.indices.filter {
            workout.exercises[exerciseIndex].sets[$0].completed
        }
        guard completedIndices.indices.contains(setIndex) else { return }
        let target = completedIndices[setIndex]
        workout.exercises[exerciseIndex].sets[target].weight = weight
        workout.exercises[exerciseIndex].sets[target].reps = reps
        activeWorkout = workout
    }

    private func applyWatchDeleteSet(_ note: Notification) {
        guard let exerciseIndex = note.userInfo?["exerciseIndex"] as? Int,
              let setIndex = note.userInfo?["setIndex"] as? Int,
              var workout = activeWorkout,
              workout.exercises.indices.contains(exerciseIndex)
        else { return }

        let completedIndices = workout.exercises[exerciseIndex].sets.indices.filter {
            workout.exercises[exerciseIndex].sets[$0].completed
        }
        guard completedIndices.indices.contains(setIndex) else { return }
        workout.exercises[exerciseIndex].sets.remove(at: completedIndices[setIndex])
        activeWorkout = workout
    }

    // MARK: - Persistence

    private var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("GymTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func save<T: Encodable>(_ value: T, as fileName: String) {
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: directory.appendingPathComponent(fileName), options: .atomic)
        } catch {
            print("Failed to save \(fileName): \(error)")
        }
    }

    private func load<T: Decodable>(_ type: T.Type, from fileName: String) -> T? {
        let url = directory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func removeFile(_ fileName: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(fileName))
    }

    // MARK: - Legacy Migration (pre-rebuild UserDefaults data)

    private struct LegacySet: Codable {
        var weight: Double
        var reps: Int
        var completed: Bool
    }

    private struct LegacyExercise: Codable {
        var name: String
        var targetSets: Int?
        var targetReps: String?
        var sets: [LegacySet]?
    }

    private struct LegacyPlan: Codable {
        var name: String
        var exercises: [LegacyExercise]
    }

    private struct LegacySession: Codable {
        var planName: String
        var date: Date
        var exercises: [LegacyExercise]
        var duration: TimeInterval?
    }

    private func migrateLegacyDataIfNeeded() {
        let defaults = UserDefaults.standard
        let migratedKey = "gym_tracker_migrated_v2"
        guard !defaults.bool(forKey: migratedKey) else { return }
        defaults.set(true, forKey: migratedKey)

        if workouts.isEmpty,
           let data = defaults.data(forKey: "gym_tracker_history"),
           let sessions = try? JSONDecoder().decode([LegacySession].self, from: data) {
            workouts = sessions.map { session in
                Workout(
                    name: session.planName,
                    date: session.date,
                    duration: session.duration ?? 0,
                    exercises: session.exercises.compactMap { exercise -> WorkoutExercise? in
                        let completed = (exercise.sets ?? [])
                            .filter(\.completed)
                            .map { WorkoutSet(weight: $0.weight, reps: $0.reps, completed: true) }
                        return completed.isEmpty ? nil : WorkoutExercise(name: exercise.name, sets: completed)
                    }
                )
            }
            .sorted { $0.date > $1.date }
            save(workouts, as: FileName.workouts)
        }

        if routines.isEmpty,
           let data = defaults.data(forKey: "gym_tracker_plans"),
           let plans = try? JSONDecoder().decode([LegacyPlan].self, from: data) {
            routines = plans.map { plan in
                Routine(name: plan.name, exercises: plan.exercises.map { exercise in
                    let reps = Int((exercise.targetReps ?? "").components(separatedBy: CharacterSet(charactersIn: "-,")).first?
                        .trimmingCharacters(in: .whitespaces) ?? "") ?? 10
                    return RoutineExercise(name: exercise.name, setCount: max(exercise.targetSets ?? 3, 1), reps: reps)
                })
            }
            save(routines, as: FileName.routines)
        }

        // Make sure every exercise name from migrated data is in the library.
        var names = Set(exercises.map { $0.name.lowercased() })
        for name in routines.flatMap({ $0.exercises.map(\.name) }) + workouts.flatMap({ $0.exercises.map(\.name) }) {
            if names.insert(name.lowercased()).inserted {
                exercises.append(Exercise(name: name))
            }
        }
        if !exercises.isEmpty {
            exercises.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            save(exercises, as: FileName.exercises)
        }
    }

    private func seedExercisesIfNeeded() {
        guard exercises.isEmpty else { return }
        let starters = [
            "Bench Press", "Incline Dumbbell Press", "Overhead Press", "Push-Up",
            "Squat", "Leg Press", "Romanian Deadlift", "Deadlift", "Hip Thrust",
            "Leg Curl", "Leg Extension", "Calf Raise",
            "Barbell Row", "Lat Pulldown", "Pull-Up", "Seated Cable Row", "Face Pull",
            "Dumbbell Curl", "Hammer Curl", "Tricep Pushdown", "Lateral Raise", "Plank"
        ]
        exercises = starters.sorted().map { Exercise(name: $0) }
        save(exercises, as: FileName.exercises)
    }
}
