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
    @State private var activeTimer: Timer?
    @State private var startTime = Date()
    @State private var showCancelAlert = false
    @State private var isRestoredWorkout = false

    var exerciseGroups: [[Int]] {
        var groups: [[Int]] = []
        var processedIndices = Set<Int>()

        for (index, exercise) in plan.exercises.enumerated() {
            if processedIndices.contains(index) { continue }

            if let supersetId = exercise.supersetId {
                var group: [Int] = []
                for (i, ex) in plan.exercises.enumerated() {
                    if ex.supersetId == supersetId {
                        group.append(i)
                        processedIndices.insert(i)
                    }
                }
                groups.append(group)
            } else {
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

    var completedSetsCount: Int {
        plan.exercises.reduce(0) { $0 + $1.sets.filter(\.completed).count }
    }

    var totalSetsCount: Int {
        plan.exercises.reduce(0) { $0 + $1.sets.count }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        progressHeader

                        if isSuperset {
                            supersetBadge
                        }

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

                        Spacer(minLength: 180)
                    }
                    .padding(.top, 12)
                }

                VStack(spacing: 0) {
                    Spacer()

                    RestTimerBannerView(
                        timeRemaining: $restTimeRemaining,
                        isActive: $timerActive,
                        onStart: { seconds in
                            startRestTimer(seconds: seconds)
                        },
                        onStop: {
                            stopRestTimer(sendToWatch: true)
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                    navigationButtons
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .padding(.top, 8)
                        .background(.ultraThinMaterial)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showCancelAlert = true
                    } label: {
                        Text("Cancel")
                            .foregroundColor(.red)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(plan.name)
                        .font(.headline)
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
                if let inProgress = dataManager.inProgressWorkout, inProgress.planId == plan.id {
                    plan.exercises = inProgress.exercises
                    currentGroupIndex = inProgress.currentExerciseIndex
                    startTime = inProgress.startTime
                    isRestoredWorkout = true
                } else {
                    saveInProgressWorkout()
                }
                watchManager.sendWorkoutToWatch(plan: plan)
                // Send the initial exercise index to the watch (first exercise of current group)
                if currentGroupIndex < exerciseGroups.count, let firstExerciseIndex = exerciseGroups[currentGroupIndex].first {
                    watchManager.sendExerciseIndexToWatch(firstExerciseIndex)
                }
            }
            .onChange(of: plan.exercises) { _, _ in
                saveInProgressWorkout()
                watchManager.updateWorkoutOnWatch(plan: plan)
            }
            .onChange(of: currentGroupIndex) { _, _ in
                saveInProgressWorkout()
            }
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
            .onReceive(NotificationCenter.default.publisher(for: .watchDidStartTimer)) { notification in
                handleWatchTimerStart(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: .watchDidStopTimer)) { _ in
                stopRestTimer(sendToWatch: false)
            }
        }
    }

    // MARK: - Progress Header
    private var progressHeader: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isSuperset ? "Superset" : "Exercise")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text("\(currentGroupIndex + 1) of \(exerciseGroups.count)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Sets Done")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text("\(completedSetsCount)/\(totalSetsCount)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 6)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(currentGroupIndex + 1) / CGFloat(max(exerciseGroups.count, 1)), height: 6)
                        .animation(.easeInOut(duration: 0.3), value: currentGroupIndex)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .padding(.horizontal, 16)
    }

    private var supersetBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 12, weight: .semibold))
            Text("SUPERSET")
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundColor(.purple)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.purple.opacity(0.12))
        .cornerRadius(20)
    }

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentGroupIndex > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        changeExerciseIndex(to: currentGroupIndex - 1)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Previous")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
            }

            if currentGroupIndex < exerciseGroups.count - 1 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        changeExerciseIndex(to: currentGroupIndex + 1)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Next")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            } else {
                Button {
                    finishWorkout()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                        Text("Finish Workout")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(allSetsCompleted ? Color.green : Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Event Handlers
    private func handleWatchTimerStart(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let seconds = userInfo["seconds"] as? Int else { return }
        startRestTimer(seconds: seconds, sendToWatch: false)
    }

    private func changeExerciseIndex(to index: Int) {
        currentGroupIndex = index
        // Send the first exercise index of the current group to the watch
        // The watch uses a flat exercise list, not groups
        if index < exerciseGroups.count, let firstExerciseIndex = exerciseGroups[index].first {
            watchManager.sendExerciseIndexToWatch(firstExerciseIndex)
        }
    }

    private func handleWatchExerciseChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let exerciseIndex = userInfo["exerciseIndex"] as? Int else { return }

        // Find which group contains this exercise index
        for (groupIndex, group) in exerciseGroups.enumerated() {
            if group.contains(exerciseIndex) {
                currentGroupIndex = groupIndex
                return
            }
        }
    }

    private func handleWatchSetComplete(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let exerciseIndex = userInfo["exerciseIndex"] as? Int,
              let weight = userInfo["weight"] as? Double,
              let reps = userInfo["reps"] as? Int,
              exerciseIndex < plan.exercises.count else { return }

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
        saveInProgressWorkout()

        if !isSuperset || allExercisesCompletedForSet(setIndex) {
            startRestTimer(seconds: 90)
        }
    }

    private func startRestTimer(seconds: Int, sendToWatch: Bool = true) {
        // Invalidate any existing timer before creating a new one
        activeTimer?.invalidate()

        restTimeRemaining = seconds
        timerActive = true
        showTimer = true

        if sendToWatch {
            watchManager.sendTimerToWatch(seconds: seconds)
        }

        activeTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if restTimeRemaining > 0 && timerActive {
                restTimeRemaining -= 1
            } else {
                timer.invalidate()
                activeTimer = nil
                timerActive = false
            }
        }
    }

    private func stopRestTimer(sendToWatch: Bool = true) {
        activeTimer?.invalidate()
        activeTimer = nil
        timerActive = false
        restTimeRemaining = 0

        if sendToWatch {
            watchManager.sendTimerStopToWatch()
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
        watchManager.endWorkoutOnWatch()

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

// MARK: - Exercise Card View
struct ExerciseCardView: View {
    let exercise: Exercise
    let exerciseIndex: Int
    @Binding var plan: WorkoutPlan
    let isSuperset: Bool
    let onSetComplete: (Int) -> Void
    let onDataChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Exercise Header
            VStack(alignment: .leading, spacing: 10) {
                Text(exercise.name)
                    .font(.system(size: isSuperset ? 20 : 24, weight: .bold, design: .rounded))

                HStack(spacing: 16) {
                    Label("\(exercise.targetSets) sets", systemImage: "repeat")
                    Label("\(exercise.targetReps) reps", systemImage: "number")
                    if let tempo = exercise.tempo {
                        Label(tempo, systemImage: "metronome")
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)

                if let notes = exercise.notes {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.orange)
                        Text(notes)
                    }
                    .font(.caption)
                    .padding(10)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }

                if let previousWeight = exercise.previousWeight {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.blue)
                        Text("Last: \(Int(previousWeight)) lbs")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(10)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }

            // Sets
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
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSuperset ? Color.purple.opacity(0.25) : Color.clear, lineWidth: 2)
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Set Row View
struct SetRowView: View {
    let setNumber: Int
    @Binding var set: SetEntry
    let onComplete: () -> Void

    @FocusState private var weightFocused: Bool
    @FocusState private var repsFocused: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Set number badge
            Text("\(setNumber)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(set.completed ? .white : .secondary)
                .frame(width: 28, height: 28)
                .background(set.completed ? Color.green : Color(.systemGray5))
                .cornerRadius(8)

            // Weight input
            VStack(alignment: .leading, spacing: 3) {
                Text("Weight")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                HStack(spacing: 4) {
                    TextField("0", text: Binding(
                        get: {
                            if set.weight == 0 && !weightFocused { return "" }
                            // Show decimals if present, otherwise show whole number
                            if set.weight.truncatingRemainder(dividingBy: 1) == 0 {
                                return String(format: "%.0f", set.weight)
                            } else {
                                return String(format: "%.1f", set.weight)
                            }
                        },
                        set: { set.weight = Double($0) ?? 0 }
                    ))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .frame(width: 64)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                    .focused($weightFocused)

                    Text("lbs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Reps input
            VStack(alignment: .leading, spacing: 3) {
                Text("Reps")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                TextField("0", text: Binding(
                    get: { set.reps == 0 && !repsFocused ? "" : String(set.reps) },
                    set: { set.reps = Int($0) ?? 0 }
                ))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .frame(width: 48)
                .padding(.vertical, 8)
                .background(Color(.systemGray5))
                .cornerRadius(8)
                .focused($repsFocused)
            }

            Spacer()

            // Complete button
            Button {
                if set.completed {
                    set.completed = false
                    set.timestamp = nil
                } else {
                    onComplete()
                }
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundColor(set.completed ? .green : Color(.systemGray3))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(set.completed ? Color.green.opacity(0.06) : Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(set.completed ? Color.green.opacity(0.2) : Color.clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Rest Timer Banner
struct RestTimerBannerView: View {
    @Binding var timeRemaining: Int
    @Binding var isActive: Bool
    let onStart: (Int) -> Void
    let onStop: () -> Void

    private let presets = [60, 90, 120, 180]

    var body: some View {
        if isActive {
            activeTimerView
        } else {
            timerPresetsView
        }
    }

    private var activeTimerView: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.2), lineWidth: 3)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: CGFloat(timeRemaining) / 180.0)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                Image(systemName: "timer")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
            }

            Text(formatTime(timeRemaining))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(timeRemaining <= 10 ? .red : .primary)

            Spacer()

            Button {
                timeRemaining += 30
            } label: {
                Text("+30s")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.12))
                    .cornerRadius(8)
            }

            Button {
                onStop()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(10)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }

    private var timerPresetsView: some View {
        HStack(spacing: 10) {
            Image(systemName: "timer")
                .font(.system(size: 14))
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
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
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
