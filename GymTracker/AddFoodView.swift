import SwiftUI

/// Pick a food from your library (recents first) or create a new one,
/// then log it to a meal.
struct AddFoodView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let meal: Meal
    let date: Date

    @State private var searchText = ""
    @State private var showNewFood = false
    @State private var describeText = ""
    @State private var isEstimating = false
    @State private var estimateError: String?
    @State private var justAddedFoodId: UUID?

    private var filteredFoods: [Food] {
        guard !searchText.isEmpty else { return store.foods }
        return store.foods.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                if CoachEngine.shared.hasAPIKey && searchText.isEmpty {
                    describeSection
                }

                if searchText.isEmpty {
                    let recents = store.recentFoods()
                    if !recents.isEmpty {
                        Section("Recent") {
                            ForEach(recents) { food in
                                foodRow(food)
                            }
                        }
                    }
                }

                Section(searchText.isEmpty ? "My Foods" : "Results") {
                    if store.foods.isEmpty {
                        emptyLibrary
                    } else if filteredFoods.isEmpty {
                        Text("No foods match \"\(searchText)\".")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredFoods) { food in
                            foodRow(food)
                        }
                    }

                    Button {
                        showNewFood = true
                    } label: {
                        Label("Create New Food", systemImage: "plus.circle.fill")
                            .fontWeight(.medium)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search foods")
            .navigationTitle("Add to \(meal.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $showNewFood) {
                FoodForm(food: Food(name: searchText)) { food in
                    store.addFood(food)
                    store.logFood(food, servings: 1, meal: meal, date: date)
                    Haptics.success()
                    dismiss()
                }
            }
        }
    }

    // MARK: - Describe It (AI estimate)

    private var describeSection: some View {
        Section {
            HStack(spacing: 10) {
                TextField("e.g. 2 eggs, toast with butter, coffee", text: $describeText, axis: .vertical)
                    .lineLimit(1...3)
                    .disabled(isEstimating)

                Button {
                    estimateAndLog()
                } label: {
                    if isEstimating {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                describeText.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? AnyShapeStyle(.tertiary)
                                    : AnyShapeStyle(Theme.gradient([.purple, .indigo]))
                            )
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isEstimating || describeText.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let estimateError {
                Text(estimateError)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        } header: {
            Label("Describe it", systemImage: "sparkles")
        } footer: {
            Text("Say what you ate in plain words — your coach estimates the calories and macros and logs it.")
        }
    }

    private func estimateAndLog() {
        let description = describeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty, !isEstimating else { return }

        isEstimating = true
        estimateError = nil
        Task {
            do {
                let food = try await CoachEngine.shared.estimateFood(description)
                store.logFood(food, servings: 1, meal: meal, date: date)
                Haptics.success()
                dismiss()
            } catch {
                estimateError = error.localizedDescription
            }
            isEstimating = false
        }
    }

    private var emptyLibrary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No foods yet")
                .fontWeight(.medium)
            Text("Create a food once and it stays in your library for one-tap logging.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func foodRow(_ food: Food) -> some View {
        NavigationLink {
            LogFoodView(food: food, meal: meal, date: date) {
                dismiss()
            }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(food.name)
                    Text(food.serving)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(food.calories.clean) cal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // One tap = one serving logged; the sheet stays open so a
                // whole meal takes seconds.
                Button {
                    quickAdd(food)
                } label: {
                    Image(systemName: justAddedFoodId == food.id ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(justAddedFoodId == food.id ? AnyShapeStyle(.green) : AnyShapeStyle(Theme.nutrition))
                        .symbolEffect(.bounce, value: justAddedFoodId == food.id)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func quickAdd(_ food: Food) {
        store.logFood(food, servings: 1, meal: meal, date: date)
        Haptics.confirm()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            justAddedFoodId = food.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if justAddedFoodId == food.id {
                justAddedFoodId = nil
            }
        }
    }
}

// MARK: - Log Food (servings + meal)

struct LogFoodView: View {
    @EnvironmentObject var store: AppStore

    let food: Food
    @State var meal: Meal
    let date: Date
    let onLogged: () -> Void

    @State private var servings: Double = 1

    init(food: Food, meal: Meal, date: Date, onLogged: @escaping () -> Void) {
        self.food = food
        self._meal = State(initialValue: meal)
        self.date = date
        self.onLogged = onLogged
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Serving")
                    Spacer()
                    Text(food.serving)
                        .foregroundStyle(.secondary)
                }
                Stepper(value: $servings, in: 0.25...50, step: 0.25) {
                    HStack {
                        Text("Servings")
                        Spacer()
                        Text(servings.clean)
                            .foregroundStyle(.secondary)
                    }
                }
                Picker("Meal", selection: $meal) {
                    ForEach(Meal.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
            }

            Section("Totals") {
                nutrientRow("Calories", food.calories * servings, unit: "cal")
                nutrientRow("Protein", food.protein * servings, unit: "g")
                nutrientRow("Carbs", food.carbs * servings, unit: "g")
                nutrientRow("Fat", food.fat * servings, unit: "g")
            }

            Section {
                Button {
                    store.logFood(food, servings: servings, meal: meal, date: date)
                    Haptics.success()
                    onLogged()
                } label: {
                    Text("Add Food")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(food.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func nutrientRow(_ name: String, _ value: Double, unit: String) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text("\(value.clean) \(unit)")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Food Form (create / edit)

struct FoodForm: View {
    @Environment(\.dismiss) private var dismiss

    @State var food: Food
    var title: String = "New Food"
    let onSave: (Food) -> Void

    var body: some View {
        Form {
            Section("Food") {
                TextField("Name (e.g. Greek Yogurt)", text: $food.name)
                TextField("Serving size (e.g. 1 cup, 100 g)", text: $food.serving)
            }

            Section("Nutrition per serving") {
                numberField("Calories", value: $food.calories, unit: "cal")
                numberField("Protein", value: $food.protein, unit: "g")
                numberField("Carbs", value: $food.carbs, unit: "g")
                numberField("Fat", value: $food.fat, unit: "g")
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(food)
                    dismiss()
                }
                .disabled(food.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func numberField(_ name: String, value: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(name)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Food Library (manage saved foods)

struct FoodLibraryView: View {
    @EnvironmentObject var store: AppStore
    @State private var searchText = ""
    @State private var showNewFood = false

    private var filteredFoods: [Food] {
        guard !searchText.isEmpty else { return store.foods }
        return store.foods.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            if store.foods.isEmpty {
                Text("Foods you create are saved here so you can log them again with one tap.")
                    .foregroundStyle(.secondary)
            }

            ForEach(filteredFoods) { food in
                NavigationLink {
                    FoodForm(food: food, title: "Edit Food") { updated in
                        store.updateFood(updated)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(food.name)
                            Text(food.serving)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(food.calories.clean) cal")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        store.deleteFood(food)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search foods")
        .navigationTitle("My Foods")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewFood = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(isPresented: $showNewFood) {
            FoodForm(food: Food(name: "")) { food in
                store.addFood(food)
            }
        }
    }
}
