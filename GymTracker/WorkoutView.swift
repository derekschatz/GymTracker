import SwiftUI
import Charts

/// Workout home: start training, routines, history, and the exercise library.
struct WorkoutView: View {
    @EnvironmentObject var store: AppStore
    @State private var editingRoutine: Routine?
    @State private var showNewRoutine = false
    @State private var routineToDelete: Routine?

    var body: some View {
        NavigationStack {
            List {
                startSection
                routinesSection
                historySection

                Section {
                    NavigationLink {
                        ExerciseLibraryView()
                    } label: {
                        Label("Exercise Library", systemImage: "list.bullet.rectangle")
                    }
                }
            }
            .navigationTitle("Workout")
            .sheet(isPresented: $showNewRoutine) {
                RoutineEditorView(routine: Routine(name: ""), isNew: true)
            }
            .sheet(item: $editingRoutine) { routine in
                RoutineEditorView(routine: routine, isNew: false)
            }
            .alert("Delete Routine?", isPresented: Binding(
                get: { routineToDelete != nil },
                set: { if !$0 { routineToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) { routineToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let routine = routineToDelete {
                        store.deleteRoutine(routine)
                    }
                    routineToDelete = nil
                }
            } message: {
                Text("Your workout history is kept.")
            }
        }
    }

    // MARK: - Start

    private var startSection: some View {
        Section {
            if store.activeWorkout != nil {
                Button {
                    store.isWorkoutPresented = true
                } label: {
                    Label("Resume Workout", systemImage: "play.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                }
            } else {
                Button {
                    store.startWorkout(name: defaultWorkoutName())
                } label: {
                    Label("Start Empty Workout", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
            }
        }
    }

    // MARK: - Routines

    private var routinesSection: some View {
        Section {
            ForEach(store.routines) { routine in
                Button {
                    if store.activeWorkout == nil {
                        store.startWorkout(from: routine)
                    } else {
                        store.isWorkoutPresented = true
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(routine.name)
                                .foregroundStyle(.primary)
                            Text(routine.exercises.map(\.name).joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "play.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        routineToDelete = routine
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        editingRoutine = routine
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }

            Button {
                showNewRoutine = true
            } label: {
                Label("New Routine", systemImage: "plus")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        } header: {
            Text("Routines")
        } footer: {
            if store.routines.isEmpty {
                Text("Save the workouts you repeat so starting takes one tap.")
            }
        }
    }

    // MARK: - History

    private var historySection: some View {
        Section("History") {
            if store.workouts.isEmpty {
                Text("Finished workouts will show up here.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.workouts.prefix(5)) { workout in
                    NavigationLink {
                        WorkoutDetailView(workout: workout)
                    } label: {
                        workoutRow(workout)
                    }
                }

                if store.workouts.count > 5 {
                    NavigationLink {
                        HistoryListView()
                    } label: {
                        Text("All Workouts (\(store.workouts.count))")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
    }

    private func workoutRow(_ workout: Workout) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 1) {
                Text(workout.date, format: .dateTime.day())
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text(workout.date, format: .dateTime.month(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(workout.name)
                    .fontWeight(.medium)
                Text("\(workout.completedSetCount) sets · \(Int(workout.totalVolume).formatted()) lb")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Full History

struct HistoryListView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        List {
            ForEach(store.workouts) { workout in
                NavigationLink {
                    WorkoutDetailView(workout: workout)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.name)
                            .fontWeight(.medium)
                        Text("\(workout.date.formatted(.dateTime.weekday().month().day())) · \(workout.completedSetCount) sets · \(Int(workout.totalVolume).formatted()) lb")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("All Workouts")
    }
}

// MARK: - Workout Detail

struct WorkoutDetailView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let workout: Workout
    @State private var showDeleteAlert = false

    var body: some View {
        List {
            Section {
                HStack {
                    summaryStat(value: workout.duration.shortDuration, label: "Duration")
                    summaryStat(value: "\(workout.completedSetCount)", label: "Sets")
                    summaryStat(value: Int(workout.totalVolume).formatted(), label: "Volume (lb)")
                }
                .padding(.vertical, 4)
            }

            ForEach(workout.exercises) { exercise in
                Section(exercise.name) {
                    ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                        HStack {
                            Text("Set \(index + 1)")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(set.weight.clean) lb × \(set.reps)")
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        store.saveAsRoutine(workout)
                    } label: {
                        Label("Save as Routine", systemImage: "square.and.arrow.down")
                    }
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete Workout", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Delete Workout?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteWorkout(workout)
                dismiss()
            }
        }
    }

    private func summaryStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Routine Editor

struct RoutineEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State var routine: Routine
    let isNew: Bool
    @State private var showExercisePicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Push Day", text: $routine.name)
                }

                Section("Exercises") {
                    ForEach($routine.exercises) { $exercise in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(exercise.name)
                                .fontWeight(.medium)
                            Stepper("\(exercise.setCount) sets", value: $exercise.setCount, in: 1...10)
                                .font(.subheadline)
                            Stepper("\(exercise.reps) reps", value: $exercise.reps, in: 1...50)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { offsets in
                        routine.exercises.remove(atOffsets: offsets)
                    }
                    .onMove { source, destination in
                        routine.exercises.move(fromOffsets: source, toOffset: destination)
                    }

                    Button {
                        showExercisePicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }
                }
            }
            .navigationTitle(isNew ? "New Routine" : "Edit Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if isNew {
                            store.addRoutine(routine)
                        } else {
                            store.updateRoutine(routine)
                        }
                        dismiss()
                    }
                    .disabled(routine.name.trimmingCharacters(in: .whitespaces).isEmpty || routine.exercises.isEmpty)
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView { name in
                    routine.exercises.append(RoutineExercise(name: name))
                }
            }
        }
    }
}

// MARK: - Exercise Picker

/// Search the library or create a custom exercise in place.
struct ExercisePickerView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let onSelect: (String) -> Void
    @State private var searchText = ""

    private var filtered: [Exercise] {
        guard !searchText.isEmpty else { return store.exercises }
        return store.exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var canCreate: Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return !store.exercises.contains { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }
    }

    var body: some View {
        NavigationStack {
            List {
                if canCreate {
                    Button {
                        select(searchText.trimmingCharacters(in: .whitespaces))
                    } label: {
                        Label("Create \"\(searchText.trimmingCharacters(in: .whitespaces))\"", systemImage: "plus.circle.fill")
                            .fontWeight(.medium)
                    }
                }

                ForEach(filtered) { exercise in
                    Button {
                        select(exercise.name)
                    } label: {
                        HStack {
                            Text(exercise.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if let last = store.lastSets(for: exercise.name)?.last {
                                Text("last: \(last.weight.clean) lb")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search or type a new exercise")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func select(_ name: String) {
        store.addExercise(named: name)
        onSelect(name)
        dismiss()
    }
}

// MARK: - Exercise Library & Progress

struct ExerciseLibraryView: View {
    @EnvironmentObject var store: AppStore
    @State private var searchText = ""
    @State private var newExerciseName = ""
    @State private var showNewExercise = false

    private var filtered: [Exercise] {
        guard !searchText.isEmpty else { return store.exercises }
        return store.exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            ForEach(filtered) { exercise in
                NavigationLink {
                    ExerciseProgressView(exerciseName: exercise.name)
                } label: {
                    Text(exercise.name)
                }
                .swipeActions {
                    Button(role: .destructive) {
                        store.deleteExercise(exercise)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle("Exercises")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newExerciseName = ""
                    showNewExercise = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("New Exercise", isPresented: $showNewExercise) {
            TextField("Exercise name", text: $newExerciseName)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                let trimmed = newExerciseName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    store.addExercise(named: trimmed)
                }
            }
        }
    }
}

struct ExerciseProgressView: View {
    @EnvironmentObject var store: AppStore
    let exerciseName: String

    var body: some View {
        let points = store.progress(for: exerciseName)

        List {
            if points.count >= 2 {
                Section("Top Weight Over Time") {
                    Chart(Array(points.enumerated()), id: \.offset) { _, point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.weight)
                        )
                        .interpolationMethod(.catmullRom)
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.weight)
                        )
                    }
                    .foregroundStyle(.blue)
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 180)
                    .padding(.vertical, 8)
                }
            }

            Section("Sessions") {
                if points.isEmpty {
                    Text("No logged sets yet. Progress appears after you complete this exercise in a workout.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(points.reversed().enumerated()), id: \.offset) { _, point in
                        HStack {
                            Text(point.date, format: .dateTime.month(.abbreviated).day().year())
                            Spacer()
                            Text("\(point.weight.clean) lb")
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
