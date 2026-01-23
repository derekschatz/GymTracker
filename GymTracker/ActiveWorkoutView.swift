import SwiftUI

struct ActiveWorkoutView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var watchManager: PhoneToWatchManager
    @State var plan: WorkoutPlan
    @Binding var isPresented: Bool

    @State private var currentGroupIndex = 0
    @State private var showTimer = false
    @State private var restTimeRemaining = 0
    @State private var timerActive = false
    @State private var startTime = Date()
    @State private var showCancelAlert = false
    @State private var isRestoredWorkout = false

    // Group exercises by supersetId - exercises with same supersetId are shown together
    var exerciseGroups: [[Int]] {
        var groups: [[Int]] = []
        var processedIndices = Set<Int>()

        for (index, exercise) in plan.exercises.enumerated() {
            if processedIndices.contains(index) { continue }

            if let supersetId = exercise.supersetId {
                // Find all exercises with the same supersetId
                var group: [Int] = []
                for (i, ex) in plan.exercises.enumerated() {
                    if ex.supersetId == supersetId {
                        group.append(i)
                        processedIndices.insert(i)
                    }
                }
                groups.append(group)
            } else {
                // Single exercise
                groups.append([index])
                processedIndices.insert(index)
            }
        }
        return groups
    }

    var currentGroup: [Int] {
        guard currentGroupIndex < exerciseGroups.count else { return [] }
        return exerciseGroups[currentGroupIndex]
    }

    var isSuperset: Bool {
        currentGroup.count > 1
    }

    var allSetsCompleted: Bool {
        plan.exercises.allSatisfy { exercise in
            exercise.sets.allSatisfy(\.completed)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // Progress indicator
                        VStack(spacing: 8) {
                            HStack {
                                if isSuperset {
                                    Text("Superset \(currentGroupIndex + 1) of \(exerciseGroups.count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Exercise \(currentGroupIndex + 1) of \(exerciseGroups.count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }

                            ProgressView(value: Double(currentGroupIndex), total: Double(exerciseGroups.count))
                                .tint(.blue)
                        }
                        .padding(.horizontal)

                        // Superset indicator
                        if isSuperset {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("SUPERSET")
                                    .fontWeight(.bold)
                            }
                            .font(.caption)
                            .foregroundColor(.purple)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.15))
                            .cornerRadius(8)
                        }

                        // Exercise cards for current group
                        ForEach(currentGroup, id: \.self) { exerciseIndex in
                            let exercise = plan.exercises[exerciseIndex]
                            ExerciseCardView(
                                exercise: exercise,
                                exerciseIndex: exerciseIndex,
                                plan: $plan,
                                isSuperset: isSuperset,
                                onSetComplete: { setIndex in
                                    completeSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
                                },
                                onDataChange: {
                                    saveInProgressWorkout()
                                }
                            )
                        }

                        Spacer(minLength: 150)
                    }
                    .padding(.top)
                }

                // Bottom section with timer and navigation
                VStack(spacing: 0) {
                    Spacer()

                    // Rest Timer
                    RestTimerBannerView(
                        timeRemaining: $restTimeRemaining,
                        isActive: $timerActive,
                        onStart: { seconds in
                            startRestTimer(seconds: seconds)
                        }
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    HStack(spacing: 16) {
                        if currentGroupIndex > 0 {
                            Button {
                                changeExerciseIndex(to: currentGroupIndex - 1)
                            } label: {
                                Label("Previous", systemImage: "chevron.left")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemGray5))
                                    .foregroundColor(.primary)
                                    .cornerRadius(12)
                            }
                        }

                        if currentGroupIndex < exerciseGroups.count - 1 {
                            Button {
                                changeExerciseIndex(to: currentGroupIndex + 1)
                            } label: {
                                Label("Next", systemImage: "chevron.right")
                                    .labelStyle(.titleAndIcon)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        } else {
                            Button {
                                finishWorkout()
                            } label: {
                                Label("Finish Workout", systemImage: "checkmark.circle.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(allSetsCompleted ? Color.green : Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showCancelAlert = true
                    }
                    .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text(plan.name)
                        .fontWeight(.semibold)
                }
            }
            .alert("Cancel Workout?", isPresented: $showCancelAlert) {
                Button("Keep Going", role: .cancel) { }
                Button("Cancel Workout", role: .destructive) {
                    dataManager.clearInProgressWorkout()
                    watchManager.endWorkoutOnWatch()
                    isPresented = false
                }
            } message: {
                Text("Your progress will be lost.")
            }
            .onAppear {
                // Check if restoring from in-progress workout
                if let inProgress = dataManager.inProgressWorkout, inProgress.planId == plan.id {
                    plan.exercises = inProgress.exercises
                    currentGroupIndex = inProgress.currentExerciseIndex
                    startTime = inProgress.startTime
                    isRestoredWorkout = true
                } else {
                    // Start fresh - save initial state
                    saveInProgressWorkout()
                }
                // Send workout to watch
                watchManager.sendWorkoutToWatch(plan: plan)
            }
            .onChange(of: plan.exercises) { _, _ in
                saveInProgressWorkout()
                // Update watch with current state
                watchManager.updateWorkoutOnWatch(plan: plan)
            }
            .onChange(of: currentGroupIndex) { _, _ in
                saveInProgressWorkout()
            }
            // Listen for watch sync notifications
            .onReceive(NotificationCenter.default.publisher(for: .watchDidCompleteSet)) { notification in
                handleWatchSetComplete(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: .watchDidUpdateSet)) { notification in
                handleWatchSetUpdate(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: .watchDidDeleteSet)) { notification in
                handleWatchSetDelete(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: .watchDidChangeExercise)) { notification in
                handleWatchExerciseChange(notification)
            }
        }
    }

    private func changeExerciseIndex(to index: Int) {
        currentGroupIndex = index
        watchManager.sendExerciseIndexToWatch(index)
    }

    private func handleWatchExerciseChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let exerciseIndex = userInfo["exerciseIndex"] as? Int,
              exerciseIndex < exerciseGroups.count else { return }

        currentGroupIndex = exerciseIndex
    }

    private func handleWatchSetComplete(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let exerciseIndex = userInfo["exerciseIndex"] as? Int,
              let weight = userInfo["weight"] as? Double,
              let reps = userInfo["reps"] as? Int,
              exerciseIndex < plan.exercises.count else { return }

        // Find the first incomplete set for this exercise
        if let setIndex = plan.exercises[exerciseIndex].sets.firstIndex(where: { !$0.completed }) {
            plan.exercises[exerciseIndex].sets[setIndex].weight = weight
            plan.exercises[exerciseIndex].sets[setIndex].reps = reps
            plan.exercises[exerciseIndex].sets[setIndex].completed = true
            plan.exercises[exerciseIndex].sets[setIndex].timestamp = Date()
        }
    }

    private func handleWatchSetUpdate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let exerciseIndex = userInfo["exerciseIndex"] as? Int,
              let setIndex = userInfo["setIndex"] as? Int,
              let weight = userInfo["weight"] as? Double,
              let reps = userInfo["reps"] as? Int,
              exerciseIndex < plan.exercises.count,
              setIndex < plan.exercises[exerciseIndex].sets.count else { return }

        plan.exercises[exerciseIndex].sets[setIndex].weight = weight
        plan.exercises[exerciseIndex].sets[setIndex].reps = reps
    }

    private func handleWatchSetDelete(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let exerciseIndex = userInfo["exerciseIndex"] as? Int,
              let setIndex = userInfo["setIndex"] as? Int,
              exerciseIndex < plan.exercises.count,
              setIndex < plan.exercises[exerciseIndex].sets.count else { return }

        plan.exercises[exerciseIndex].sets[setIndex].completed = false
        plan.exercises[exerciseIndex].sets[setIndex].timestamp = nil
    }

    private func saveInProgressWorkout() {
        let inProgress = DataManager.InProgressWorkout(
            planId: plan.id,
            planName: plan.name,
            exercises: plan.exercises,
            startTime: startTime,
            currentExerciseIndex: currentGroupIndex
        )
        dataManager.saveInProgressWorkout(inProgress)
    }

    private func completeSet(exerciseIndex: Int, setIndex: Int) {
        plan.exercises[exerciseIndex].sets[setIndex].completed = true
        plan.exercises[exerciseIndex].sets[setIndex].timestamp = Date()

        // Save progress immediately
        saveInProgressWorkout()

        // Only start rest timer after completing all exercises in superset for this set number
        // Or for non-superset, start immediately
        if !isSuperset || allExercisesCompletedForSet(setIndex) {
            startRestTimer(seconds: 90)
        }
    }

    private func startRestTimer(seconds: Int) {
        restTimeRemaining = seconds
        timerActive = true
        showTimer = true

        // Timer countdown
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if restTimeRemaining > 0 && timerActive {
                restTimeRemaining -= 1
            } else {
                timer.invalidate()
                timerActive = false
            }
        }
    }

    private func allExercisesCompletedForSet(_ setIndex: Int) -> Bool {
        for exerciseIndex in currentGroup {
            if setIndex < plan.exercises[exerciseIndex].sets.count {
                if !plan.exercises[exerciseIndex].sets[setIndex].completed {
                    return false
                }
            }
        }
        return true
    }

    private func finishWorkout() {
        let duration = Date().timeIntervalSince(startTime)
        let totalVolume = SessionRecord.calculateTotalVolume(exercises: plan.exercises)

        let session = SessionRecord(
            planId: plan.id,
            planName: plan.name,
            date: startTime,
            exercises: plan.exercises,
            totalVolume: totalVolume,
            duration: duration
        )

        dataManager.addSession(session)

        // Notify watch that workout ended
        watchManager.endWorkoutOnWatch()

        // Save to HealthKit
        Task {
            do {
                try await healthKitManager.saveWorkout(session)
            } catch {
                print("Failed to save to HealthKit: \(error)")
            }
        }

        isPresented = false
    }
}

struct ExerciseCardView: View {
    let exercise: Exercise
    let exerciseIndex: Int
    @Binding var plan: WorkoutPlan
    let isSuperset: Bool
    let onSetComplete: (Int) -> Void
    let onDataChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Exercise info header
            VStack(alignment: .leading, spacing: 8) {
                Text(exercise.name)
                    .font(isSuperset ? .title2 : .title)
                    .fontWeight(.bold)

                HStack {
                    Label("\(exercise.targetSets) sets", systemImage: "repeat")
                    Text("•")
                    Label("\(exercise.targetReps) reps", systemImage: "number")
                    if let tempo = exercise.tempo {
                        Text("•")
                        Label(tempo, systemImage: "metronome")
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)

                if let notes = exercise.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                }

                if let previousWeight = exercise.previousWeight {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("Last time: \(Int(previousWeight)) lbs")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
            }

            // Sets list
            VStack(spacing: 8) {
                ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { setIndex, set in
                    SetRowView(
                        setNumber: setIndex + 1,
                        set: Binding(
                            get: { plan.exercises[exerciseIndex].sets[setIndex] },
                            set: { newValue in
                                plan.exercises[exerciseIndex].sets[setIndex] = newValue
                                onDataChange()
                            }
                        ),
                        onComplete: {
                            onSetComplete(setIndex)
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSuperset ? Color.purple.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .padding(.horizontal)
    }
}

struct SetRowView: View {
    let setNumber: Int
    @Binding var set: SetEntry
    let onComplete: () -> Void

    @FocusState private var weightFocused: Bool
    @FocusState private var repsFocused: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Set number
            Text("\(setNumber)")
                .font(.headline)
                .foregroundColor(set.completed ? .green : .secondary)
                .frame(width: 30)

            // Weight input
            VStack(spacing: 4) {
                Text("Weight")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                HStack {
                    TextField("0", text: Binding(
                        get: { set.weight == 0 && !weightFocused ? "" : String(format: "%.0f", set.weight) },
                        set: { set.weight = Double($0) ?? 0 }
                    ))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.headline)
                        .frame(width: 60)
                        .padding(8)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                        .focused($weightFocused)
                    Text("lbs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Reps input
            VStack(spacing: 4) {
                Text("Reps")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                TextField("0", text: Binding(
                    get: { set.reps == 0 && !repsFocused ? "" : String(set.reps) },
                    set: { set.reps = Int($0) ?? 0 }
                ))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.headline)
                    .frame(width: 50)
                    .padding(8)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                    .focused($repsFocused)
            }

            Spacer()

            // Complete button - toggles completion
            Button {
                if set.completed {
                    // Uncomplete the set
                    set.completed = false
                    set.timestamp = nil
                } else {
                    // Complete the set and trigger timer
                    onComplete()
                }
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(set.completed ? .green : .blue)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(set.completed ? Color.green.opacity(0.05) : Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(set.completed ? Color.green.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }
}

struct RestTimerBannerView: View {
    @Binding var timeRemaining: Int
    @Binding var isActive: Bool
    let onStart: (Int) -> Void

    private let presets = [60, 90, 120, 180]

    var body: some View {
        if isActive {
            // Active timer display
            HStack(spacing: 16) {
                Image(systemName: "timer")
                    .font(.title2)
                    .foregroundColor(.orange)

                Text(formatTime(timeRemaining))
                    .font(.title)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundColor(timeRemaining <= 10 ? .red : .primary)

                Spacer()

                // Add time buttons
                Button {
                    timeRemaining += 30
                } label: {
                    Text("+30s")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }

                Button {
                    isActive = false
                    timeRemaining = 0
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        } else {
            // Timer presets
            HStack(spacing: 12) {
                Image(systemName: "timer")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Rest")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                ForEach(presets, id: \.self) { seconds in
                    Button {
                        onStart(seconds)
                    } label: {
                        Text(formatTimeShort(seconds))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatTimeShort(_ seconds: Int) -> String {
        if seconds >= 60 {
            let mins = seconds / 60
            let secs = seconds % 60
            return secs == 0 ? "\(mins)m" : "\(mins):\(String(format: "%02d", secs))"
        }
        return "\(seconds)s"
    }
}
