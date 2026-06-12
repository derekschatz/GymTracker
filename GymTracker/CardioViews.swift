import SwiftUI

/// 10-second cardio logging: activity → minutes → optional distance → done.
struct LogCardioSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var activity: CardioActivity = .run
    @State private var minutes: Int = 30
    @State private var distanceText = ""

    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 10)]
    private let quickMinutes = [15, 20, 30, 45, 60]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Activity")
                        .font(.headline)

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(CardioActivity.allCases) { option in
                            Button {
                                Haptics.tap()
                                activity = option
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: option.icon)
                                        .font(.title3)
                                    Text(option.title)
                                        .font(.caption2.weight(.medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundStyle(activity == option ? .white : .primary)
                                .background(
                                    activity == option
                                        ? AnyShapeStyle(Theme.gradient([.pink, .orange]))
                                        : AnyShapeStyle(Color(.secondarySystemGroupedBackground))
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.pressable)
                        }
                    }

                    Text("Duration")
                        .font(.headline)

                    HStack(spacing: 8) {
                        ForEach(quickMinutes, id: \.self) { preset in
                            Button("\(preset)") {
                                Haptics.tap()
                                minutes = preset
                            }
                            .font(.subheadline.monospacedDigit().weight(minutes == preset ? .bold : .regular))
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .tint(minutes == preset ? .pink : .gray)
                        }
                    }

                    Stepper(value: $minutes, in: 1...600, step: 5) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(minutes)")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text("min")
                                .foregroundStyle(.secondary)
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: minutes)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if activity.supportsDistance {
                        Text("Distance (optional)")
                            .font(.headline)
                        HStack {
                            TextField("0", text: $distanceText)
                                .keyboardType(.decimalPad)
                                .font(.title3.weight(.semibold))
                            Text("miles")
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Button {
                        saveEntry()
                    } label: {
                        GradientButtonLabel(title: "Save \(activity.title)", systemImage: "checkmark",
                                            colors: [.pink, .orange])
                    }
                    .buttonStyle(.pressable)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Log Cardio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func saveEntry() {
        let entry = CardioEntry(
            activity: activity,
            duration: TimeInterval(minutes * 60),
            distance: activity.supportsDistance ? Double(distanceText) : nil
        )
        store.logCardio(entry)
        Haptics.success()
        Task {
            await HealthKitManager.shared.saveCardio(entry)
        }
        dismiss()
    }
}

// MARK: - Cardio Row & History

struct CardioRow: View {
    let entry: CardioEntry

    var body: some View {
        HStack(spacing: 12) {
            GradientIcon(systemName: entry.activity.icon, colors: [.pink, .orange], size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.activity.title)
                    .fontWeight(.medium)
                Text(entry.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(entry.date, format: .dateTime.month(.abbreviated).day())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct CardioHistoryView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        List {
            ForEach(store.cardioEntries) { entry in
                CardioRow(entry: entry)
                    .swipeActions {
                        Button(role: .destructive) {
                            store.deleteCardio(entry)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .navigationTitle("Cardio")
    }
}
