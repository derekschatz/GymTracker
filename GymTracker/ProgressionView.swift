import SwiftUI

struct ProgressionView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedExercise: String?

    var allExerciseNames: [String] {
        let exercises = dataManager.history.flatMap { $0.exercises.map { $0.name } }
        return Array(Set(exercises)).sorted()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection

                    if dataManager.history.isEmpty {
                        emptyStateView
                    } else {
                        statsOverview
                        exercisesList
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Progression")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Track your strength gains")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
            }
            VStack(spacing: 6) {
                Text("No Data Yet")
                    .font(.headline)
                Text("Complete workouts to see your progression")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Stats Overview
    private var statsOverview: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Workouts",
                value: "\(dataManager.history.count)",
                icon: "figure.strengthtraining.traditional",
                color: .blue
            )

            StatCard(
                title: "Exercises",
                value: "\(allExerciseNames.count)",
                icon: "list.bullet",
                color: .purple
            )

            StatCard(
                title: "Total Volume",
                value: formatVolume(dataManager.history.reduce(0) { $0 + $1.totalVolume }),
                icon: "scalemass",
                color: .green
            )
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Exercises List
    private var exercisesList: some View {
        VStack(spacing: 14) {
            HStack {
                Text("By Exercise")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 20)

            VStack(spacing: 10) {
                ForEach(allExerciseNames, id: \.self) { exerciseName in
                    ExerciseProgressionCard(
                        exerciseName: exerciseName,
                        history: dataManager.getExerciseHistory(for: exerciseName)
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1_000_000 {
            return String(format: "%.1fM", volume / 1_000_000)
        } else if volume >= 1_000 {
            return String(format: "%.0fK", volume / 1_000)
        }
        return "\(Int(volume))"
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
}

// MARK: - Exercise Progression Card
struct ExerciseProgressionCard: View {
    let exerciseName: String
    let history: [(date: Date, weight: Double)]
    @State private var isExpanded = false

    var latestWeight: Double? {
        history.last?.weight
    }

    var weightChange: Double? {
        guard history.count >= 2 else { return nil }
        let first = history.first?.weight ?? 0
        let last = history.last?.weight ?? 0
        return last - first
    }

    var progressPercentage: Double? {
        guard history.count >= 2,
              let first = history.first?.weight, first > 0 else { return nil }
        let last = history.last?.weight ?? 0
        return ((last - first) / first) * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 14) {
                    // Progress indicator
                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray5), lineWidth: 3)
                            .frame(width: 44, height: 44)

                        if let change = weightChange {
                            Circle()
                                .trim(from: 0, to: min(abs(change) / 50, 1))
                                .stroke(
                                    change >= 0 ? Color.green : Color.red,
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                                .frame(width: 44, height: 44)
                                .rotationEffect(.degrees(-90))
                        }

                        Image(systemName: weightChange ?? 0 >= 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(weightChange ?? 0 >= 0 ? .green : .red)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(exerciseName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        if let latest = latestWeight {
                            HStack(spacing: 8) {
                                Text("\(Int(latest)) lbs")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.blue)

                                if let change = weightChange, change != 0 {
                                    HStack(spacing: 3) {
                                        Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                                            .font(.system(size: 10, weight: .bold))
                                        Text("\(Int(abs(change)))")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundColor(change > 0 ? .green : .red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background((change > 0 ? Color.green : Color.red).opacity(0.12))
                                    .cornerRadius(6)
                                }
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded && !history.isEmpty {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, 14)

                    VStack(spacing: 12) {
                        // Mini progress bar
                        if let percentage = progressPercentage {
                            HStack {
                                Text("Progress")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(String(format: "%+.1f%%", percentage))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(percentage >= 0 ? .green : .red)
                            }

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color(.systemGray5))
                                        .frame(height: 6)

                                    Capsule()
                                        .fill(percentage >= 0 ? Color.green : Color.red)
                                        .frame(width: min(geometry.size.width * abs(percentage) / 100, geometry.size.width), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }

                        // History list
                        VStack(spacing: 6) {
                            ForEach(history.suffix(5).reversed(), id: \.date) { session in
                                HStack {
                                    Text(session.date, format: .dateTime.month(.abbreviated).day())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 60, alignment: .leading)

                                    ProgressBarView(
                                        value: session.weight,
                                        maxValue: history.map(\.weight).max() ?? 100
                                    )

                                    Text("\(Int(session.weight)) lbs")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .frame(width: 55, alignment: .trailing)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(.tertiarySystemGroupedBackground))
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
}

// MARK: - Progress Bar View
struct ProgressBarView: View {
    let value: Double
    let maxValue: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemGray5))
                    .frame(height: 8)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * (value / max(maxValue, 1)), height: 8)
            }
        }
        .frame(height: 8)
    }
}
