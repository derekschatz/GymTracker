import SwiftUI
import Charts

/// The dashboard: today's nutrition, training, and body weight at a glance.
struct TodayView: View {
    @EnvironmentObject var store: AppStore
    @State private var showSettings = false
    @State private var showLogWeight = false
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    caloriesCard
                    workoutCard
                    weightCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background {
                ZStack {
                    Color(.systemGroupedBackground)
                    LinearGradient(
                        colors: [Color.orange.opacity(0.08), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                }
                .ignoresSafeArea()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showLogWeight) {
                LogWeightSheet()
                    .presentationDetents([.height(280)])
            }
            .onAppear {
                withAnimation(.spring(response: 1.0, dampingFraction: 0.85).delay(0.15)) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Header

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(greeting)
                .font(.system(size: 32, weight: .bold, design: .rounded))
        }
        .padding(.top, 4)
    }

    // MARK: - Calories

    private var caloriesCard: some View {
        let totals = store.nutritionTotals(on: Date())
        let goal = max(store.goals.calories, 1)
        let remaining = store.goals.calories - totals.calories

        return VStack(spacing: 20) {
            HStack(spacing: 22) {
                ZStack {
                    ActivityRing(
                        progress: appeared ? totals.calories / goal : 0,
                        colors: Theme.nutritionColors
                    )
                    VStack(spacing: 2) {
                        Text(abs(remaining).clean)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text(remaining >= 0 ? "cal left" : "cal over")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 132, height: 132)

                VStack(alignment: .leading, spacing: 16) {
                    miniStat(icon: "flame.fill", colors: Theme.nutritionColors,
                             label: "Eaten", value: "\(totals.calories.clean) cal")
                    miniStat(icon: "target", colors: Theme.trainingColors,
                             label: "Goal", value: "\(store.goals.calories.clean) cal")
                }
                Spacer(minLength: 0)
            }

            VStack(spacing: 12) {
                macroRow("Protein", value: totals.protein, target: store.goals.protein,
                         showTarget: true, colors: [.red, .orange])
                macroRow("Carbs", value: totals.carbs, target: goal * 0.5 / 4,
                         showTarget: false, colors: [.orange, .yellow])
                macroRow("Fat", value: totals.fat, target: goal * 0.3 / 9,
                         showTarget: false, colors: [.yellow, .pink])
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: totals.calories)
        .card()
    }

    private func miniStat(icon: String, colors: [Color], label: String, value: String) -> some View {
        HStack(spacing: 10) {
            GradientIcon(systemName: icon, colors: colors, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
    }

    private func macroRow(_ name: String, value: Double, target: Double,
                          showTarget: Bool, colors: [Color]) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text(name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(showTarget ? "\(value.clean) / \(target.clean) g" : "\(value.clean) g")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            GradientBar(
                progress: appeared && target > 0 ? value / target : 0,
                colors: colors,
                height: 8
            )
        }
    }

    // MARK: - Workout

    @ViewBuilder
    private var workoutCard: some View {
        let todaysWorkouts = store.workouts(on: Date())

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                GradientIcon(systemName: "dumbbell.fill", colors: Theme.trainingColors, size: 30)
                Text("Training")
                    .font(.headline)
                Spacer()
            }

            if store.activeWorkout != nil {
                Button {
                    store.isWorkoutPresented = true
                } label: {
                    GradientButtonLabel(title: "Resume Workout", systemImage: "play.fill",
                                        colors: Theme.successColors)
                }
                .buttonStyle(.pressable)
            } else if let workout = todaysWorkouts.first {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title)
                        .foregroundStyle(Theme.success)
                        .symbolEffect(.bounce, value: appeared)
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
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                Button {
                    Haptics.confirm()
                    store.startWorkout(name: defaultWorkoutName())
                } label: {
                    GradientButtonLabel(title: "Start Workout", systemImage: "plus",
                                        colors: Theme.trainingColors)
                }
                .buttonStyle(.pressable)
            }
        }
        .card()
    }

    // MARK: - Weight

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                GradientIcon(systemName: "scalemass.fill", colors: Theme.weightColors, size: 30)
                Text("Body Weight")
                    .font(.headline)
                Spacer()
                Button {
                    showLogWeight = true
                } label: {
                    Text("Log")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Theme.weight)
                        .clipShape(Capsule())
                }
                .buttonStyle(.pressable)
            }

            if let latest = store.latestWeight {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(latest.weight.clean)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("lb")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    if store.weightEntries.count >= 2 {
                        let delta = latest.weight - store.weightEntries[1].weight
                        if delta != 0 {
                            HStack(spacing: 2) {
                                Image(systemName: delta < 0 ? "arrow.down.right" : "arrow.up.right")
                                Text(abs(delta).clean)
                            }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(delta < 0 ? Color.teal : Color.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((delta < 0 ? Color.teal : Color.orange).opacity(0.12))
                            .clipShape(Capsule())
                            .padding(.leading, 4)
                        }
                    }

                    Spacer()
                    Text(latest.date, format: .dateTime.month(.abbreviated).day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: latest.weight)

                weightChart
            } else {
                Text("Log your weight to start tracking the trend.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    @ViewBuilder
    private var weightChart: some View {
        let recent = Array(store.weightEntries.prefix(30).reversed())
        if recent.count >= 2 {
            let weights = recent.map(\.weight)
            let floor = (weights.min() ?? 0) - 2
            let ceiling = (weights.max() ?? 0) + 2

            Chart(recent) { entry in
                AreaMark(
                    x: .value("Date", entry.date),
                    yStart: .value("Base", floor),
                    yEnd: .value("Weight", entry.weight)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.teal.opacity(0.25), Color.teal.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Date", entry.date),
                    y: .value("Weight", entry.weight)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Theme.weight)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
            .chartYScale(domain: floor...ceiling)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 80)
        }
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
            VStack(spacing: 24) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("0", text: $weightText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
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
                        Haptics.success()
                    }
                    dismiss()
                } label: {
                    GradientButtonLabel(title: "Save", systemImage: "checkmark",
                                        colors: Theme.weightColors)
                }
                .buttonStyle(.pressable)
                .disabled(Double(weightText) == nil)
                .padding(.horizontal, 24)
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
