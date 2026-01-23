import SwiftUI

struct WatchWorkoutView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    let workout: WatchWorkout

    @State private var currentExerciseIndex = 0
    @State private var restTimer = 0
    @State private var timerActive = false

    var currentExercise: WatchExercise? {
        guard currentExerciseIndex < workout.exercises.count else { return nil }
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
    }

    var exerciseView: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let exercise = currentExercise {
                    // Exercise name
                    Text(exercise.name)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    // Sets info
                    Text("\(exercise.completedSets)/\(exercise.targetSets) sets")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Target reps
                    Text("\(exercise.targetReps) reps")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Divider()

                    // Quick log buttons
                    HStack(spacing: 8) {
                        ForEach(exercise.quickWeights, id: \.self) { weight in
                            Button {
                                logSet(weight: weight)
                            } label: {
                                Text("\(Int(weight))")
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                        }
                    }

                    // Complete set button (uses last weight)
                    Button {
                        logSet(weight: exercise.lastWeight ?? 0)
                    } label: {
                        Label("Log Set", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    // Navigation
                    HStack {
                        if currentExerciseIndex > 0 {
                            Button {
                                currentExerciseIndex -= 1
                            } label: {
                                Image(systemName: "chevron.left")
                            }
                        }

                        Spacer()

                        Text("\(currentExerciseIndex + 1)/\(workout.exercises.count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Spacer()

                        if currentExerciseIndex < workout.exercises.count - 1 {
                            Button {
                                currentExerciseIndex += 1
                            } label: {
                                Image(systemName: "chevron.right")
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding()
        }
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
                        timerActive = false
                        restTimer = 0
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

    private func logSet(weight: Double) {
        workoutManager.logSet(
            exerciseIndex: currentExerciseIndex,
            weight: weight,
            reps: Int(currentExercise?.targetReps.components(separatedBy: "-").first ?? "0") ?? 0
        )

        // Start rest timer
        startTimer(seconds: 90)
    }

    private func startTimer(seconds: Int) {
        restTimer = seconds
        timerActive = true

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if restTimer > 0 && timerActive {
                restTimer -= 1
            } else {
                timer.invalidate()
                timerActive = false
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
