import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Workout", systemImage: "dumbbell.fill")
                }
                .tag(0)

            ProgressionView()
                .tabItem {
                    Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(1)
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showImporter = false
    @State private var selectedPlan: WorkoutPlan?
    @State private var showDeleteAlert = false
    @State private var planToDelete: WorkoutPlan?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Workouts")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Ready for your session, Derek?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    // My Plans Section
                    VStack(spacing: 16) {
                        HStack {
                            Label("My Plans", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .foregroundColor(.blue)
                            Spacer()
                            Button("Import New") {
                                showImporter = true
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal)

                        if dataManager.plans.isEmpty {
                            Button(action: { showImporter = true }) {
                                VStack(spacing: 12) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary)
                                    Text("No plans yet. Tap to import.")
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 150)
                                .background(Color(.systemGray6))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(.systemGray4), style: StrokeStyle(lineWidth: 2, dash: [8]))
                                )
                            }
                            .padding(.horizontal)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(dataManager.plans) { plan in
                                    Button {
                                        startWorkout(plan: plan)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(plan.name)
                                                    .font(.title3)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.primary)
                                                Text("\(plan.exercises.count) Exercises")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.blue)
                                                .padding(10)
                                                .background(Color.blue.opacity(0.1))
                                                .clipShape(Circle())
                                        }
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(16)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            planToDelete = plan
                                            showDeleteAlert = true
                                        } label: {
                                            Label("Delete Plan", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Recent Activity Section
                    VStack(spacing: 16) {
                        HStack {
                            Label("Recent Activity", systemImage: "clock.fill")
                                .font(.headline)
                                .foregroundColor(.green)
                            Spacer()
                        }
                        .padding(.horizontal)

                        if dataManager.history.isEmpty {
                            Text("No sessions logged yet.")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(dataManager.history.prefix(3)) { session in
                                    HStack(spacing: 16) {
                                        Image(systemName: "calendar")
                                            .font(.system(size: 20))
                                            .foregroundColor(.secondary)
                                            .frame(width: 40, height: 40)
                                            .background(Color(.systemGray5))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(session.planName)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                            Text("\(session.date, style: .date) • \(Int(session.totalVolume).formatted()) lbs")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6).opacity(0.5))
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    Spacer(minLength: 80)
                }
                .padding(.top)
            }
            .sheet(isPresented: $showImporter) {
                ImporterView(isPresented: $showImporter)
            }
            .fullScreenCover(item: $selectedPlan) { plan in
                ActiveWorkoutView(plan: plan, isPresented: Binding(
                    get: { selectedPlan != nil },
                    set: { if !$0 { selectedPlan = nil } }
                ))
            }
            .alert("Delete Plan?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    planToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let plan = planToDelete {
                        dataManager.deletePlan(plan)
                    }
                    planToDelete = nil
                }
            } message: {
                if let plan = planToDelete {
                    Text("Are you sure you want to delete \"\(plan.name)\"? This cannot be undone.")
                }
            }
        }
    }

    private func startWorkout(plan: WorkoutPlan) {
        var enrichedPlan = plan
        enrichedPlan.exercises = plan.exercises.map { exercise in
            var ex = exercise
            ex.previousWeight = dataManager.getPreviousWeight(for: exercise.name)
            ex.sets = ex.createDefaultSets()
            return ex
        }
        selectedPlan = enrichedPlan
    }
}
