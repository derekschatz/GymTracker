import SwiftUI
import Charts

/// The dashboard: today's nutrition, training, and body weight at a glance.
struct TodayView: View {
    @EnvironmentObject var store: AppStore
    @State private var showSettings = false
    @State private var showLogWeight = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    caloriesCard
                    workoutCard
                    weightCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showLogWeight) {
                LogWeightSheet()
                    .presentationDetents([.height(260)])
            }
        }
    }

    // MARK: - Calories

    private var caloriesCard: some View {
        let totals = store.nutritionTotals(on: Date())
        let goal = max(store.goals.calories, 1)
        let remaining = store.goals.calories - totals.calories

        return VStack(spacing: 16) {
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.15), lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: min(totals.calories / goal, 1))
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text(abs(remaining).clean)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        Text(remaining >= 0 ? "left" : "over")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 120, height: 120)

                VStack(alignment: .leading, spacing: 12) {
                    statRow(label: "Eaten", value: "\(totals.calories.clean) cal")
                    statRow(label: "Goal", value: "\(store.goals.calories.clean) cal")
                    statRow(label: "Protein", value: "\(totals.protein.clean) / \(store.goals.protein.clean) g")
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                macroChip(name: "Protein", grams: totals.protein, color: .red)
                macroChip(name: "Carbs", grams: totals.carbs, color: .orange)
                macroChip(name: "Fat", grams: totals.fat, color: .yellow)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    private func macroChip(name: String, grams: Double, color: Color) -> some View {
        VStack(spacing: 3) {
            Text("\(grams.clean)g")
                .font(.subheadline)
                .fontWeight(.bold)
            Text(name)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Workout

    @ViewBuilder
    private var workoutCard: some View {
        let todaysWorkouts = store.workouts(on: Date())

        VStack(alignment: .leading, spacing: 12) {
            Label("Training", systemImage: "dumbbell.fill")
                .font(.headline)

            if store.activeWorkout != nil {
                Button {
                    store.isWorkoutPresented = true
                } label: {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("Resume Workout")
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding(12)
                    .background(Color.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else if let workout = todaysWorkouts.first {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.name)
                            .fontWeight(.semibold)
                        Text("\(workout.completedSetCount) sets · \(Int(workout.totalVolume).formatted()) lb · \(workout.duration.shortDuration)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Button {
                    store.startWorkout(name: defaultWorkoutName())
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Start Workout")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.12))
                    .foregroundStyle(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Weight

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Body Weight", systemImage: "scalemass.fill")
                    .font(.headline)
                Spacer()
                Button("Log") {
                    showLogWeight = true
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
            }

            if let latest = store.latestWeight {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(latest.weight.clean)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("lb")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(latest.date, format: .dateTime.month(.abbreviated).day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                let recent = Array(store.weightEntries.prefix(30)).reversed()
                if recent.count >= 2 {
                    Chart(Array(recent)) { entry in
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", entry.weight)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.blue)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 90)
                }
            } else {
                Text("Log your weight to start tracking the trend.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

func defaultWorkoutName(date: Date = Date()) -> String {
    let hour = Calendar.current.component(.hour, from: date)
    switch hour {
    case 4..<12: return "Morning Workout"
    case 12..<17: return "Afternoon Workout"
    default: return "Evening Workout"
    }
}

// MARK: - Log Weight Sheet

struct LogWeightSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var weightText = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("0", text: $weightText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.trailing)
                        .fixedSize()
                        .focused($focused)
                    Text("lb")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Button {
                    if let weight = Double(weightText), weight > 0 {
                        store.logWeight(weight)
                    }
                    dismiss()
                } label: {
                    Text("Save")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(Double(weightText) == nil)
                .padding(.horizontal)
            }
            .padding(.top, 24)
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if let latest = store.latestWeight {
                    weightText = latest.weight.clean
                }
                focused = true
            }
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("2000", value: $store.goals.calories, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("cal")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Protein")
                        Spacer()
                        TextField("150", value: $store.goals.protein, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("g")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Daily Goals")
                } footer: {
                    Text("Used for the progress rings on the Today and Nutrition screens.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
