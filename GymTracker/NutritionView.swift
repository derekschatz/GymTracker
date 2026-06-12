import SwiftUI

/// Daily food log: meals, totals, and quick day switching.
struct NutritionView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedDate = Date()
    @State private var addFoodMeal: Meal?
    @State private var editingEntry: FoodEntry?

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    dateNavigator
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    summary
                }

                ForEach(Meal.allCases) { meal in
                    mealSection(meal)
                }
            }
            .navigationTitle("Nutrition")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        FoodLibraryView()
                    } label: {
                        Image(systemName: "books.vertical")
                    }
                }
            }
            .sheet(item: $addFoodMeal) { meal in
                AddFoodView(meal: meal, date: selectedDate)
            }
            .sheet(item: $editingEntry) { entry in
                EditFoodEntrySheet(entry: entry)
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Header

    private var dateNavigator: some View {
        HStack {
            Button {
                shiftDay(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                withAnimation { selectedDate = Date() }
            } label: {
                Text(isToday ? "Today" : selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.headline)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                shiftDay(1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .disabled(isToday)
            .opacity(isToday ? 0.3 : 1)
        }
        .foregroundStyle(.primary)
    }

    private var summary: some View {
        let totals = store.nutritionTotals(on: selectedDate)
        let goal = max(store.goals.calories, 1)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(totals.calories.clean)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("/ \(store.goals.calories.clean) cal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if totals.calories > 0 {
                    Text("\(Int(min(totals.calories / goal, 9.99) * 100))%")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(totals.calories > goal ? Theme.gradient([.orange, .red]) : Theme.nutrition)
                        .clipShape(Capsule())
                }
            }

            GradientBar(
                progress: totals.calories / goal,
                colors: totals.calories > goal ? [.orange, .red] : Theme.nutritionColors,
                height: 10
            )

            HStack {
                macroLabel("P", totals.protein, .red)
                macroLabel("C", totals.carbs, .orange)
                macroLabel("F", totals.fat, .yellow)
                Spacer()
            }
        }
        .padding(.vertical, 6)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: totals.calories)
    }

    private func macroLabel(_ letter: String, _ grams: Double, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(letter)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            Text("\(grams.clean)g")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
        .padding(.trailing, 10)
    }

    // MARK: - Meals

    private func mealSection(_ meal: Meal) -> some View {
        let entries = store.foodEntries(on: selectedDate, meal: meal)
        let calories = entries.reduce(0) { $0 + $1.calories }

        return Section {
            ForEach(entries) { entry in
                Button {
                    editingEntry = entry
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.food.name)
                                .foregroundStyle(.primary)
                            Text(servingText(for: entry))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(entry.calories.clean) cal")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        store.deleteFoodEntry(entry)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            Button {
                addFoodMeal = meal
            } label: {
                Label("Add Food", systemImage: "plus.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            // Same breakfast as yesterday? One tap.
            if entries.isEmpty, let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate),
               !store.foodEntries(on: yesterday, meal: meal).isEmpty {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        store.copyMeal(meal, from: yesterday, to: selectedDate)
                    }
                    Haptics.success()
                } label: {
                    Label("Same as yesterday", systemImage: "arrow.uturn.left.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            HStack(spacing: 8) {
                GradientIcon(systemName: meal.icon, colors: meal.colors, size: 24)
                Text(meal.title)
                Spacer()
                if calories > 0 {
                    Text("\(calories.clean) cal")
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: calories)
        }
    }

    private func servingText(for entry: FoodEntry) -> String {
        entry.servings == 1 ? entry.food.serving : "\(entry.servings.clean) × \(entry.food.serving)"
    }

    private func shiftDay(_ days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            withAnimation { selectedDate = newDate }
        }
    }
}

// MARK: - Edit Entry

struct EditFoodEntrySheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var entry: FoodEntry

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(entry.food.name)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(entry.calories.clean) cal")
                            .foregroundStyle(.secondary)
                    }

                    Stepper(value: $entry.servings, in: 0.25...50, step: 0.25) {
                        HStack {
                            Text("Servings")
                            Spacer()
                            Text(entry.servings.clean)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Picker("Meal", selection: $entry.meal) {
                        ForEach(Meal.allCases) { meal in
                            Text(meal.title).tag(meal)
                        }
                    }
                }

                Section {
                    Button("Delete Entry", role: .destructive) {
                        store.deleteFoodEntry(entry)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateFoodEntry(entry)
                        Haptics.tap()
                        dismiss()
                    }
                }
            }
        }
    }
}
