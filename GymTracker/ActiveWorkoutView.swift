import SwiftUI

/// The live workout session. All exercises are visible in one scrolling
/// list — no paging, no modes. Stays in sync with the Apple Watch.
struct ActiveWorkoutView: View {
    @EnvironmentObject var store: AppStore

    @State private var showAddExercise = false
    @State private var showFinishConfirm = false
    @State private var showCancelConfirm = false

    // Rest timer
    @State private var restEndDate: Date?
    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            Group {
                if let workout = store.activeWorkout {
                    workoutList(workout)
                } else {
                    // Finished/cancelled from elsewhere (e.g. the watch).
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()
                        .onAppear { store.isWorkoutPresented = false }
                }
            }
            .navigationTitle(store.activeWorkout?.name ?? "Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showCancelConfirm = true
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") {
                        if hasIncompleteSets {
                            showFinishConfirm = true
                        } else {
                            finish()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(completedSetCount == 0 && (store.activeWorkout?.exercises.isEmpty ?? true))
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                restTimerBar
            }
            .sheet(isPresented: $showAddExercise) {
                ExercisePickerView { name in
                    store.activeWorkout?.exercises.append(store.newWorkoutExercise(named: name))
                }
            }
            .confirmationDialog("Some sets aren't checked off.", isPresented: $showFinishConfirm, titleVisibility: .visible) {
                Button("Finish Anyway") { finish() }
                Button("Keep Going", role: .cancel) {}
            } message: {
                Text("Only completed sets are saved.")
            }
            .confirmationDialog("End this workout?", isPresented: $showCancelConfirm, titleVisibility: .visible) {
                Button("Discard Workout", role: .destructive) {
                    store.cancelActiveWorkout()
                    store.isWorkoutPresented = false
                }
                Button("Minimize", role: .cancel) {
                    store.isWorkoutPresented = false
                }
            } message: {
                Text("Minimize keeps the workout running so you can come back to it.")
            }
            .onReceive(tick) { _ in
                if let end = restEndDate, end <= Date() {
                    restEndDate = nil
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .watchDidStartTimer)) { note in
                if let seconds = note.userInfo?["seconds"] as? Int {
                    restEndDate = Date().addingTimeInterval(TimeInterval(seconds))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .watchDidStopTimer)) { _ in
                restEndDate = nil
            }
        }
    }

    // MARK: - List

    private func workoutList(_ workout: ActiveWorkout) -> some View {
        List {
            Section {
                HStack {
                    Label {
                        Text(timerInterval: workout.startDate...Date.distantFuture, countsDown: false)
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(completedSetCount)/\(totalSetCount) sets")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(workout.exercises) { exercise in
                exerciseSection(exercise)
            }

            Section {
                Button {
                    showAddExercise = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func exerciseSection(_ exercise: WorkoutExercise) -> some View {
        Section {
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                SetRow(
                    index: index,
                    set: setBinding(exerciseId: exercise.id, setId: set.id),
                    onComplete: {
                        if !set.completed, restEndDate == nil {
                            startRest(seconds: 90)
                        }
                    }
                )
            }
            .onDelete { offsets in
                deleteSets(exerciseId: exercise.id, at: offsets)
            }

            Button {
                addSet(to: exercise.id)
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.subheadline)
            }
        } header: {
            HStack {
                Text(exercise.name)
                Spacer()
                if let last = store.lastSets(for: exercise.name)?.last {
                    Text("last: \(last.weight.clean) lb × \(last.reps)")
                        .textCase(nil)
                }
                Menu {
                    Button(role: .destructive) {
                        removeExercise(exercise.id)
                    } label: {
                        Label("Remove Exercise", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                }
            }
        }
    }

    // MARK: - Rest Timer Bar

    @ViewBuilder
    private var restTimerBar: some View {
        if store.activeWorkout != nil {
            HStack(spacing: 10) {
                if let end = restEndDate, end > Date() {
                    Image(systemName: "timer")
                        .foregroundStyle(.orange)
                    Text(timerInterval: Date()...end, countsDown: true)
                        .font(.title3.monospacedDigit())
                        .fontWeight(.semibold)
                    Spacer()
                    Button("+30s") {
                        restEndDate = end.addingTimeInterval(30)
                        sendTimerToWatch()
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    Button {
                        stopRest()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Rest")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    ForEach([60, 90, 120, 180], id: \.self) { seconds in
                        Button(restLabel(seconds)) {
                            startRest(seconds: seconds)
                        }
                        .font(.subheadline.monospacedDigit())
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    private func restLabel(_ seconds: Int) -> String {
        seconds % 60 == 0 ? "\(seconds / 60):00" : "\(seconds / 60):\(seconds % 60)"
    }

    private func startRest(seconds: Int) {
        restEndDate = Date().addingTimeInterval(TimeInterval(seconds))
        sendTimerToWatch()
    }

    private func stopRest() {
        restEndDate = nil
        PhoneToWatchManager.shared.sendTimerStopToWatch()
    }

    private func sendTimerToWatch() {
        if let end = restEndDate {
            let remaining = Int(end.timeIntervalSinceNow.rounded())
            if remaining > 0 {
                PhoneToWatchManager.shared.sendTimerToWatch(seconds: remaining)
            }
        }
    }

    // MARK: - Mutations

    private func setBinding(exerciseId: UUID, setId: UUID) -> Binding<WorkoutSet> {
        Binding(
            get: {
                store.activeWorkout?.exercises
                    .first(where: { $0.id == exerciseId })?
                    .sets.first(where: { $0.id == setId }) ?? WorkoutSet()
            },
            set: { newValue in
                guard let exerciseIndex = store.activeWorkout?.exercises.firstIndex(where: { $0.id == exerciseId }),
                      let setIndex = store.activeWorkout?.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setId })
                else { return }
                store.activeWorkout?.exercises[exerciseIndex].sets[setIndex] = newValue
            }
        )
    }

    private func addSet(to exerciseId: UUID) {
        guard let index = store.activeWorkout?.exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        let last = store.activeWorkout?.exercises[index].sets.last
        store.activeWorkout?.exercises[index].sets.append(
            WorkoutSet(weight: last?.weight ?? 0, reps: last?.reps ?? 10)
        )
    }

    private func removeExercise(_ exerciseId: UUID) {
        store.activeWorkout?.exercises.removeAll { $0.id == exerciseId }
    }

    private func deleteSets(exerciseId: UUID, at offsets: IndexSet) {
        guard let index = store.activeWorkout?.exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        store.activeWorkout?.exercises[index].sets.remove(atOffsets: offsets)
        if store.activeWorkout?.exercises[index].sets.isEmpty == true {
            store.activeWorkout?.exercises.remove(at: index)
        }
    }

    private var completedSetCount: Int {
        store.activeWorkout?.exercises.reduce(0) { $0 + $1.completedSets.count } ?? 0
    }

    private var totalSetCount: Int {
        store.activeWorkout?.exercises.reduce(0) { $0 + $1.sets.count } ?? 0
    }

    private var hasIncompleteSets: Bool {
        completedSetCount < totalSetCount
    }

    private func finish() {
        stopRest()
        if let workout = store.finishActiveWorkout() {
            Task {
                await HealthKitManager.shared.saveWorkout(workout)
            }
        }
        store.isWorkoutPresented = false
    }
}

// MARK: - Set Row

private struct SetRow: View {
    let index: Int
    @Binding var set: WorkoutSet
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.subheadline.monospacedDigit())
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: 22)

            TextField("0", value: $set.weight, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .padding(.vertical, 6)
                .frame(width: 70)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("lb ×")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("0", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .padding(.vertical, 6)
                .frame(width: 50)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()

            Button {
                let wasCompleted = set.completed
                set.completed.toggle()
                if !wasCompleted {
                    onComplete()
                }
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.completed ? .green : .secondary)
            }
            .buttonStyle(.plain)
        }
        .listRowBackground(set.completed ? Color.green.opacity(0.08) : nil)
    }
}
