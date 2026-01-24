import SwiftUI

struct WatchWorkoutView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    let workout: WatchWorkout

    @State private var selectedWeight: Double = 0
    @State private var restTimer = 0
    @State private var timerActive = false
    @State private var showingSetsSheet = false
    @State private var isUpdatingFromPhone = false

    var currentExerciseIndex: Int {
        workoutManager.currentExerciseIndex
    }

    var currentExercise: WatchExercise? {
        guard let workout = workoutManager.activeWorkout,
              currentExerciseIndex < workout.exercises.count else { return nil }
        return workout.exercises[currentExerciseIndex]
    }

    var body: some View {
        TabView {
            // Exercise View
            exerciseView

            // Timer View
            timerView
        }
        .tabViewStyle(.verticalPage)
        .onAppear {
            // Initialize weight from last used or previous weight
            if let exercise = currentExercise {
                selectedWeight = exercise.lastWeight ?? 0
            }
        }
        .onChange(of: workoutManager.currentExerciseIndex) { _, _ in
            // Update weight when switching exercises
            if let exercise = currentExercise {
                selectedWeight = exercise.lastWeight ?? 0
            }
        }
        .onChange(of: workoutManager.timerSecondsFromPhone) { _, newValue in
            // Start timer when phone sends timer event
            if let seconds = newValue {
                startTimer(seconds: seconds, sendToPhone: false)
                workoutManager.timerSecondsFromPhone = nil
            }
        }
        .onChange(of: workoutManager.timerStopFromPhone) { _, newValue in
            // Stop timer when phone sends stop event
            if newValue {
                stopTimer(sendToPhone: false)
                workoutManager.timerStopFromPhone = false
            }
        }
        .sheet(isPresented: $showingSetsSheet) {
            SetsEditView(
                exerciseIndex: currentExerciseIndex,
                exercise: currentExercise
            )
            .environmentObject(workoutManager)
        }
    }

    var exerciseView: some View {
        VStack(spacing: 4) {
            if let exercise = currentExercise {
                Spacer()
                    .frame(height: 8)

                // Exercise name - long press to edit sets
                Text(exercise.name)
                    .font(.system(size: 17, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .onLongPressGesture {
                        showingSetsSheet = true
                    }

                // Sets and reps info - also tappable to edit
                Text("\(exercise.completedSets)/\(exercise.targetSets) sets • \(repsForSet(exercise: exercise, setIndex: exercise.completedSets)) reps")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .onTapGesture {
                        if exercise.completedSets > 0 {
                            showingSetsSheet = true
                        }
                    }

                // Tempo display
                if let tempo = exercise.tempo {
                    Text(tempo)
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }

                // Weight selector with +/- buttons
                HStack(spacing: 10) {
                    // Minus 5
                    Button {
                        selectedWeight = max(0, selectedWeight - 5)
                    } label: {
                        Image(systemName: "minus")
                            .font(.body)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    // Weight display (scrollable with Digital Crown)
                    VStack(spacing: 0) {
                        Text("\(Int(selectedWeight))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        Text("lbs")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(minWidth: 55)
                    .focusable()
                    .digitalCrownRotation(
                        $selectedWeight,
                        from: 0,
                        through: 500,
                        by: 1,
                        sensitivity: .medium,
                        isContinuous: false,
                        isHapticFeedbackEnabled: true
                    )

                    // Plus 5
                    Button {
                        selectedWeight = min(500, selectedWeight + 5)
                    } label: {
                        Image(systemName: "plus")
                            .font(.body)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                }

                // Bottom row: back arrow, log set checkmark, next arrow
                HStack(spacing: 12) {
                    // Back button
                    if currentExerciseIndex > 0 {
                        Button {
                            changeExercise(to: currentExerciseIndex - 1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        // Placeholder for alignment
                        Color.clear.frame(width: 44, height: 44)
                    }

                    // Log Set checkmark or completion message
                    if exercise.completedSets < exercise.targetSets {
                        Button {
                            logSet(weight: selectedWeight)
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    } else {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }

                    // Next button
                    if currentExerciseIndex < (workoutManager.activeWorkout?.exercises.count ?? 1) - 1 {
                        Button {
                            changeExercise(to: currentExerciseIndex + 1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.title3)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        // Placeholder for alignment
                        Color.clear.frame(width: 44, height: 44)
                    }
                }
                .padding(.top, 4)

                // Exercise counter
                Text("\(currentExerciseIndex + 1)/\(workoutManager.activeWorkout?.exercises.count ?? 0)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }

    var timerView: some View {
        VStack(spacing: 16) {
            Text(formatTime(restTimer))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(timerActive ? (restTimer <= 10 ? .red : .orange) : .primary)

            if timerActive {
                HStack(spacing: 12) {
                    Button {
                        restTimer += 30
                    } label: {
                        Text("+30s")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        stopTimer(sendToPhone: true)
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            } else {
                HStack(spacing: 8) {
                    ForEach([60, 90, 120], id: \.self) { seconds in
                        Button {
                            startTimer(seconds: seconds)
                        } label: {
                            Text(seconds == 60 ? "1m" : seconds == 90 ? "1:30" : "2m")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private func changeExercise(to index: Int) {
        workoutManager.currentExerciseIndex = index
        workoutManager.sendExerciseIndexToPhone(index)
    }

    private func logSet(weight: Double) {
        guard let exercise = currentExercise else { return }

        // Don't log if already at set limit
        guard exercise.completedSets < exercise.targetSets else { return }

        // Determine reps for this set
        let reps = repsForSet(exercise: exercise, setIndex: exercise.completedSets)

        workoutManager.logSet(
            exerciseIndex: currentExerciseIndex,
            weight: weight,
            reps: reps
        )

        // Check if this was the last set
        let newCompletedSets = exercise.completedSets + 1
        if newCompletedSets >= exercise.targetSets {
            // Move to next exercise if available
            if currentExerciseIndex < (workoutManager.activeWorkout?.exercises.count ?? 1) - 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.changeExercise(to: self.currentExerciseIndex + 1)
                }
            }
        }

        // Start rest timer
        startTimer(seconds: 90)
    }

    private func startTimer(seconds: Int, sendToPhone: Bool = true) {
        restTimer = seconds
        timerActive = true

        if sendToPhone {
            workoutManager.sendTimerToPhone(seconds)
        }

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if restTimer > 0 && timerActive {
                restTimer -= 1
            } else {
                timer.invalidate()
                timerActive = false
            }
        }
    }

    private func stopTimer(sendToPhone: Bool = true) {
        timerActive = false
        restTimer = 0

        if sendToPhone {
            workoutManager.sendTimerStopToPhone()
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func repsForSet(exercise: WatchExercise, setIndex: Int) -> Int {
        // Check if reps are comma-separated (e.g., "10, 10, 8, 6")
        let commaSeparated = exercise.targetReps.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        if commaSeparated.count > 1 {
            // Use the rep value for this specific set
            let repString = setIndex < commaSeparated.count ? commaSeparated[setIndex] : commaSeparated.last ?? "0"
            // Handle if individual rep is a range like "8-10" - use first number
            return Int(repString.components(separatedBy: "-").first ?? "0") ?? 0
        } else {
            // Single value or range (e.g., "10" or "8-10")
            return Int(exercise.targetReps.components(separatedBy: "-").first ?? "0") ?? 0
        }
    }
}

// MARK: - Sets Edit View
struct SetsEditView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @Environment(\.dismiss) var dismiss

    let exerciseIndex: Int
    let exercise: WatchExercise?

    var loggedSets: [WatchSetEntry] {
        workoutManager.activeWorkout?.exercises[exerciseIndex].loggedSets ?? []
    }

    var body: some View {
        NavigationStack {
            List {
                if loggedSets.isEmpty {
                    Text("No sets logged yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(loggedSets.enumerated()), id: \.element.id) { index, set in
                        NavigationLink {
                            SetEditDetailView(
                                exerciseIndex: exerciseIndex,
                                setIndex: index,
                                initialWeight: set.weight,
                                initialReps: set.reps
                            )
                            .environmentObject(workoutManager)
                        } label: {
                            HStack {
                                Text("Set \(index + 1)")
                                    .font(.headline)
                                Spacer()
                                Text("\(Int(set.weight)) lbs × \(set.reps)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            workoutManager.deleteSet(exerciseIndex: exerciseIndex, setIndex: index)
                        }
                    }
                }
            }
            .navigationTitle("Sets")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Set Edit Detail View
struct SetEditDetailView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @Environment(\.dismiss) var dismiss

    let exerciseIndex: Int
    let setIndex: Int

    @State var editWeight: Double
    @State var editReps: Int

    init(exerciseIndex: Int, setIndex: Int, initialWeight: Double, initialReps: Int) {
        self.exerciseIndex = exerciseIndex
        self.setIndex = setIndex
        _editWeight = State(initialValue: initialWeight)
        _editReps = State(initialValue: initialReps)
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Set \(setIndex + 1)")
                .font(.headline)

            // Weight editor
            HStack {
                Button {
                    editWeight = max(0, editWeight - 5)
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.bordered)
                .tint(.red)

                VStack(spacing: 0) {
                    Text("\(Int(editWeight))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .focusable()
                        .digitalCrownRotation(
                            $editWeight,
                            from: 0,
                            through: 500,
                            by: 1,
                            sensitivity: .medium,
                            isContinuous: false,
                            isHapticFeedbackEnabled: true
                        )
                    Text("lbs")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(minWidth: 50)

                Button {
                    editWeight = min(500, editWeight + 5)
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }

            // Reps editor
            HStack {
                Button {
                    editReps = max(1, editReps - 1)
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.bordered)
                .tint(.red)

                VStack(spacing: 0) {
                    Text("\(editReps)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("reps")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(minWidth: 50)

                Button {
                    editReps += 1
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }

            // Save button
            Button {
                workoutManager.updateSet(
                    exerciseIndex: exerciseIndex,
                    setIndex: setIndex,
                    weight: editWeight,
                    reps: editReps
                )
                dismiss()
            } label: {
                Text("Save")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding()
    }
}
