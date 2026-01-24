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
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Import Plan")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("Paste workout markdown or load an example")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Quick actions
                    HStack(spacing: 12) {
                        Button {
                            markdownText = WorkoutParser.exampleWorkout()
                            showExample = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 16))
                                Text("Load Example")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }

                        Button {
                            markdownText = ""
                            errorMessage = nil
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                    .font(.system(size: 16))
                                Text("Clear")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                        }
                    }

                    // Text editor section
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Workout Markdown")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Spacer()

                            if !markdownText.isEmpty {
                                Text("\(markdownText.components(separatedBy: .newlines).filter { !$0.isEmpty }.count) lines")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        ZStack(alignment: .topLeading) {
                            if markdownText.isEmpty {
                                Text("# Workout Name\n## Exercise 1\nSets: 3\nReps: 10\n\n## Exercise 2\nSets: 4\nReps: 8-12")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.secondary.opacity(0.5))
                                    .padding(12)
                            }

                            TextEditor(text: $markdownText)
                                .font(.system(.body, design: .monospaced))
                                .scrollContentBackground(.hidden)
                                .padding(8)
                        }
                        .frame(minHeight: 240)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                    }

                    // Error message
                    if let error = errorMessage {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                    }

                    // Format guide
                    formatGuideSection

                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        importWorkout()
                    } label: {
                        Text("Import")
                            .fontWeight(.semibold)
                    }
                    .disabled(markdownText.isEmpty)
                }
            }
        }
    }

    private var formatGuideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Format Guide")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            VStack(spacing: 8) {
                FormatGuideRow(prefix: "#", description: "Workout name", example: "# Push Day")
                FormatGuideRow(prefix: "##", description: "Exercise name", example: "## Bench Press")
                FormatGuideRow(prefix: "Sets:", description: "Number of sets", example: "Sets: 4")
                FormatGuideRow(prefix: "Reps:", description: "Target reps", example: "Reps: 8-10")
                FormatGuideRow(prefix: "Tempo:", description: "Tempo (optional)", example: "Tempo: 3-1-2")
                FormatGuideRow(prefix: "Notes:", description: "Notes (optional)", example: "Notes: Pause at bottom")
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    private func importWorkout() {
        do {
            let plans = try WorkoutParser.parse(markdown: markdownText)
            dataManager.addPlans(plans)
            isPresented = false
        } catch {
            let lineCount = markdownText.components(separatedBy: .newlines).filter { !$0.isEmpty }.count
            errorMessage = "Failed to parse workout. Check your format (\(lineCount) lines detected)."
        }
    }
}

struct FormatGuideRow: View {
    let prefix: String
    let description: String
    let example: String

    var body: some View {
        HStack(spacing: 12) {
            Text(prefix)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.blue)
                .frame(width: 50, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.primary)
                Text(example)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}
