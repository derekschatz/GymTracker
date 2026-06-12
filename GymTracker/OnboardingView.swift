import SwiftUI

/// 30-second setup: four taps and the coach handles the rest.
struct OnboardingView: View {
    @EnvironmentObject var store: AppStore

    @State private var goal: UserProfile.Goal = .stayHealthy
    @State private var experience: UserProfile.Experience = .beginner
    @State private var daysPerWeek = 3
    @State private var equipment: UserProfile.Equipment = .fullGym

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        GradientIcon(systemName: "sparkles", colors: [.purple, .indigo], size: 48)
                        Text("Welcome")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("Four quick answers so your coach knows you. You can change these anytime.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 12)

                    section("What's your goal?") {
                        VStack(spacing: 8) {
                            ForEach(UserProfile.Goal.allCases) { option in
                                choiceRow(
                                    title: option.title,
                                    icon: option.icon,
                                    selected: goal == option
                                ) {
                                    goal = option
                                }
                            }
                        }
                    }

                    section("How experienced are you?") {
                        Picker("Experience", selection: $experience) {
                            ForEach(UserProfile.Experience.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    section("How many days a week can you train?") {
                        Stepper(value: $daysPerWeek, in: 1...7) {
                            Text("\(daysPerWeek) days")
                                .font(.headline)
                                .monospacedDigit()
                        }
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    section("What equipment do you have?") {
                        VStack(spacing: 8) {
                            ForEach(UserProfile.Equipment.allCases) { option in
                                choiceRow(
                                    title: option.title,
                                    icon: "checkmark",
                                    showIcon: false,
                                    selected: equipment == option
                                ) {
                                    equipment = option
                                }
                            }
                        }
                    }

                    Button {
                        Haptics.success()
                        store.profile = UserProfile(
                            goal: goal,
                            experience: experience,
                            daysPerWeek: daysPerWeek,
                            equipment: equipment
                        )
                    } label: {
                        GradientButtonLabel(title: "Let's Go", systemImage: "arrow.right",
                                            colors: [.purple, .indigo])
                    }
                    .buttonStyle(.pressable)
                    .padding(.top, 6)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
        }
        .interactiveDismissDisabled()
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func choiceRow(title: String, icon: String, showIcon: Bool = true,
                           selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 12) {
                if showIcon {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(Theme.gradient([.purple, .indigo])))
                        .frame(width: 24)
                }
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(selected ? .white : .primary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .padding(14)
            .background(
                selected
                    ? AnyShapeStyle(Theme.gradient([.purple, .indigo]))
                    : AnyShapeStyle(Color(.secondarySystemGroupedBackground))
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.pressable)
    }
}
