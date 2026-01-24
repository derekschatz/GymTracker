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
        .tint(.blue)
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
                VStack(spacing: 28) {
                    // Header
                    headerSection

                    // My Plans Section
                    plansSection

                    // Recent Activity Section
                    recentActivitySection

                    Spacer(minLength: 100)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
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
                        withAnimation(.easeOut(duration: 0.2)) {
                            dataManager.deletePlan(plan)
                        }
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

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Workouts")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Ready for your session?")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    // MARK: - Plans Section
    private var plansSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("My Plans")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    showImporter = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("Import")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)

            if dataManager.plans.isEmpty {
                emptyPlansCard
            } else {
                VStack(spacing: 10) {
                    ForEach(dataManager.plans) { plan in
                        planCard(plan: plan)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var emptyPlansCard: some View {
        Button(action: { showImporter = true }) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 56, height: 56)
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.blue)
                }
                VStack(spacing: 4) {
                    Text("Add Workout Plan")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Import from markdown")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    .foregroundColor(Color(.systemGray3))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private func planCard(plan: WorkoutPlan) -> some View {
        Button {
            startWorkout(plan: plan)
        } label: {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: [.blue, .blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 48, height: 48)
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text("\(plan.exercises.count) exercises")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "play.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                    .padding(10)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 2)
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

    // MARK: - Recent Activity Section
    private var recentActivitySection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Recent Activity")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 20)

            if dataManager.history.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No workouts yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                VStack(spacing: 8) {
                    ForEach(dataManager.history.prefix(5)) { session in
                        sessionCard(session: session)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func sessionCard(session: SessionRecord) -> some View {
        HStack(spacing: 14) {
            // Date indicator
            VStack(spacing: 2) {
                Text(session.date, format: .dateTime.day())
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(session.date, format: .dateTime.month(.abbreviated))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            .frame(width: 44)

            Rectangle()
                .fill(Color(.systemGray4))
                .frame(width: 1, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.planName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack(spacing: 12) {
                    Label("\(Int(session.totalVolume).formatted()) lbs", systemImage: "scalemass")
                    if let duration = session.duration {
                        Label(formatDuration(duration), systemImage: "clock")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
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

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m"
    }
}
