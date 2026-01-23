import SwiftUI
import UniformTypeIdentifiers

struct ImporterView: View {
    @EnvironmentObject var dataManager: DataManager
    @Binding var isPresented: Bool
    @State private var markdownText = ""
    @State private var showFilePicker = false
    @State private var errorMessage: String?
    @State private var showExample = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Import Workout Plan")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Paste your workout markdown or load a file")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Example button
                    Button {
                        markdownText = WorkoutParser.exampleWorkout()
                        showExample = true
                    } label: {
                        Label("Load Example Workout", systemImage: "text.badge.plus")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                    }

                    // Text editor
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Workout Markdown")
                            .font(.headline)

                        TextEditor(text: $markdownText)
                            .frame(minHeight: 300)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .font(.system(.body, design: .monospaced))
                    }

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }

                    // Format guide
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Format Guide")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            FormatGuideRow(prefix: "#", description: "Workout name")
                            FormatGuideRow(prefix: "##", description: "Exercise name")
                            FormatGuideRow(prefix: "Sets:", description: "Number of sets")
                            FormatGuideRow(prefix: "Reps:", description: "Target reps (e.g., 8-10)")
                            FormatGuideRow(prefix: "Notes:", description: "Optional notes")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }

                    Spacer()
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") {
                        importWorkout()
                    }
                    .disabled(markdownText.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func importWorkout() {
        do {
            let plans = try WorkoutParser.parse(markdown: markdownText)
            dataManager.addPlans(plans)
            isPresented = false
        } catch {
            errorMessage = "Failed to parse workout: \(error.localizedDescription)"
        }
    }
}

struct FormatGuideRow: View {
    let prefix: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Text(prefix)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .frame(width: 60, alignment: .leading)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
