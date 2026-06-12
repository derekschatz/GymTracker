import SwiftUI
import Combine

/// The live workout session. All exercises are visible in one scrolling
/// list — no paging, no modes. Stays in sync with the Apple Watch.
struct ActiveWorkoutView: View {
    @EnvironmentObject var store: AppStore

    @State private var showAddExercise = false
    @State private var showFinishConfirm = false
    @State private var showCancelConfirm = false
    @State private var finishedWorkout: Workout?

    // Rest timer
    @State private var restEndDate: Date?
    @State private var restDuration: TimeInterval = 90
    @State private var now = Date()
    private let tick = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            Group {
                if let workout = store.activeWorkout {
                    workoutList(workout)
                } else {
                    // Finished/cancelled from elsewhere (e.g. the watch).
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()
                        .onAppear {
                            if finishedWorkout == nil {
                                store.isWorkoutPresented = false
                            }
                        }
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
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        store.activeWorkout?.exercises.append(store.newWorkoutExercise(named: name))
                    }
                }
            }
            .sheet(item: $finishedWorkout, onDismiss: { store.isWorkoutPresented = false }) { workout in
                WorkoutCompleteView(workout: workout)
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
            .onReceive(tick) { date in
                guard let end = restEndDate else { return }
                now = date
                if end <= date {
                    restEndDate = nil
                    Haptics.success()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .watchDidStartTimer)) { note in
                if let seconds = note.userInfo?["seconds"] as? Int {
                    restDuration = TimeInterval(seconds)
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
                VStack(spacing: 10) {
                    HStack {
                        Label {
                            Text(timerInterval: workout.startDate...Date.distantFuture, countsDown: false)
                                .monospacedDigit()
                        } icon: {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(Theme.training)
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(completedSetCount)/\(totalSetCount) sets")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .foregroundStyle(.secondary)
                    }

                    GradientBar(
                        progress: totalSetCount > 0 ? Double(completedSetCount) / Double(totalSetCount) : 0,
                        colors: Theme.trainingColors,
                        height: 8
                    )
                }
                .padding(.vertical, 4)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: completedSetCount)
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
                        .foregroundStyle(Theme.training)
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
                Haptics.tap()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    addSet(to: exercise.id)
                }
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.subheadline.weight(.medium))
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
            HStack(spacing: 12) {
                if let end = restEndDate, end > now {
                    restRing(end: end)
                    Text(timerInterval: Date()...end, countsDown: true)
                        .font(.title3.weight(.semibold).monospacedDigit())
                    Spacer()
                    Button("+30s") {
                        Haptics.tap()
                        restEndDate = end.addingTimeInterval(30)
                        restDuration += 30
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
                    Image(systemName: "timer")
                        .foregroundStyle(.secondary)
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

    private func restRing(end: Date) -> some View {
        let remaining = max(end.timeIntervalSince(now), 0)
        let fraction = restDuration > 0 ? remaining / restDuration : 0

        return ZStack {
            Circle()
                .stroke(Color.orange.opacity(0.2), lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(min(fraction, 1), 0.001))
                .stroke(
                    Theme.gradient([.orange, .red]),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: fraction)
        }
        .frame(width: 26, height: 26)
    }

    private func restLabel(_ seconds: Int) -> String {
        seconds % 60 == 0 ? "\(seconds / 60):00" : "\(seconds / 60):\(seconds % 60)"
    }

    private func startRest(seconds: Int) {
        Haptics.tap()
        restDuration = TimeInterval(seconds)
        restEndDate = Date().addingTimeInterval(TimeInterval(seconds))
        now = Date()
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
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            store.activeWorkout?.exercises.removeAll { $0.id == exerciseId }
        }
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
            finishedWorkout = workout
        } else {
            store.isWorkoutPresented = false
        }
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
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    set.completed.toggle()
                }
                if wasCompleted {
                    Haptics.tap()
                } else {
                    Haptics.confirm()
                    onComplete()
                }
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.completed ? AnyShapeStyle(Theme.success) : AnyShapeStyle(.secondary))
                    .symbolEffect(.bounce, value: set.completed)
            }
            .buttonStyle(.plain)
        }
        .listRowBackground(set.completed ? Color.green.opacity(0.08) : nil)
    }
}

// MARK: - Workout Complete

struct WorkoutCompleteView: View {
    let workout: Workout
    @Environment(\.dismiss) private var dismiss
    @State private var celebrate = false

    var body: some View {
        VStack(spacing: 26) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 150, height: 150)
                    .scaleEffect(celebrate ? 1 : 0.4)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 74))
                    .foregroundStyle(Theme.success)
                    .scaleEffect(celebrate ? 1 : 0.3)
                    .rotationEffect(.degrees(celebrate ? 0 : -25))
                    .symbolEffect(.bounce, value: celebrate)
                    .shadow(color: .green.opacity(0.35), radius: 14, x: 0, y: 6)
            }

            VStack(spacing: 4) {
                Text("Workout Complete")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(workout.name)
                    .foregroundStyle(.secondary)
            }
            .opacity(celebrate ? 1 : 0)
            .offset(y: celebrate ? 0 : 12)

            HStack(spacing: 12) {
                stat(value: workout.duration.shortDuration, label: "Duration",
                     icon: "clock.fill", colors: Theme.trainingColors)
                stat(value: "\(workout.completedSetCount)", label: "Sets",
                     icon: "checklist", colors: Theme.successColors)
                stat(value: Int(workout.totalVolume).formatted(), label: "Volume (lb)",
                     icon: "scalemass.fill", colors: Theme.weightColors)
            }
            .padding(.horizontal, 20)
            .opacity(celebrate ? 1 : 0)
            .offset(y: celebrate ? 0 : 16)

            Spacer()

            Button {
                dismiss()
            } label: {
                GradientButtonLabel(title: "Done", systemImage: "checkmark",
                                    colors: Theme.successColors)
            }
            .buttonStyle(.pressable)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            Haptics.success()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65).delay(0.1)) {
                celebrate = true
            }
        }
    }

    private func stat(value: String, label: String, icon: String, colors: [Color]) -> some View {
        VStack(spacing: 7) {
            GradientIcon(systemName: icon, colors: colors, size: 34)
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
