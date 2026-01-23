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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Progression")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Track your strength over time")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    if dataManager.history.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text("No workout data yet")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Complete your first workout to see progression charts")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(40)
                    } else {
                        VStack(spacing: 16) {
                            ForEach(allExerciseNames, id: \.self) { exerciseName in
                                ExerciseProgressionCard(
                                    exerciseName: exerciseName,
                                    history: dataManager.getExerciseHistory(for: exerciseName)
                                )
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 80)
                }
                .padding(.top)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exerciseName)
                            .font(.headline)
                            .foregroundColor(.primary)

                        if let latest = latestWeight {
                            HStack(spacing: 8) {
                                Text("\(Int(latest)) lbs")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)

                                if let change = weightChange, change != 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                                        Text("\(Int(abs(change))) lbs")
                                    }
                                    .font(.caption)
                                    .foregroundColor(change > 0 ? .green : .red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background((change > 0 ? Color.green : Color.red).opacity(0.1))
                                    .cornerRadius(6)
                                }
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded && !history.isEmpty {
                // Simplified chart view (Charts framework requires iOS 16+)
                VStack(spacing: 8) {
                    Text("Weight Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(history, id: \.date) { data in
                        HStack {
                            Text(data.date, style: .date)
                                .font(.caption)
                            Spacer()
                            Text("\(Int(data.weight)) lbs")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)
                .padding(.top, 8)

                // Sessions summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(history.suffix(5).reversed(), id: \.date) { session in
                        HStack {
                            Text(session.date, style: .date)
                                .font(.caption)
                            Spacer()
                            Text("\(Int(session.weight)) lbs")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}
