import SwiftUI

/// Chat with your coach. The coach sees all your data and can take
/// actions — building routines and setting targets — not just talk.
struct CoachView: View {
    @EnvironmentObject var store: AppStore

    @State private var draft = ""
    @State private var isThinking = false
    @State private var errorText: String?
    @State private var showSettings = false
    @State private var showClearConfirm = false
    @FocusState private var inputFocused: Bool

    private let suggestions = [
        "What should I do today?",
        "Build me a workout plan",
        "Set my calorie and protein targets",
        "I've been off for two weeks — plan my comeback"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !CoachEngine.shared.hasAPIKey {
                    setupState
                } else if store.coachMessages.isEmpty {
                    emptyState
                } else {
                    conversation
                }

                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.orange.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                }

                if CoachEngine.shared.hasAPIKey {
                    inputBar
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        if !store.coachMessages.isEmpty {
                            Button(role: .destructive) {
                                showClearConfirm = true
                            } label: {
                                Label("Clear Conversation", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .confirmationDialog("Clear this conversation?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear", role: .destructive) {
                    store.clearCoachConversation()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your data and plans are kept — only the chat is cleared.")
            }
        }
    }

    // MARK: - States

    private var setupState: some View {
        ScrollView {
            VStack(spacing: 18) {
                GradientIcon(systemName: "sparkles", colors: [.purple, .indigo], size: 64)
                    .padding(.top, 48)

                Text("Meet your coach")
                    .font(.system(size: 26, weight: .bold, design: .rounded))

                Text("A real coach sees your training, your food, and your weight — then tells you the one thing to do today. Yours lives here, knows your data, and builds your plans for you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                VStack(alignment: .leading, spacing: 10) {
                    Label("Knows your lifts, food log, and weight trend", systemImage: "chart.line.uptrend.xyaxis")
                    Label("Builds and updates your routines itself", systemImage: "dumbbell.fill")
                    Label("No streaks, no guilt — built for comebacks", systemImage: "arrow.uturn.up")
                }
                .font(.subheadline)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)

                Button {
                    showSettings = true
                } label: {
                    GradientButtonLabel(title: "Add Claude API Key", systemImage: "key.fill",
                                        colors: [.purple, .indigo])
                }
                .buttonStyle(.pressable)
                .padding(.horizontal, 24)

                Text("Get a key at console.anthropic.com. Tracking works fully offline — only coach chats use the network.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 16) {
                GradientIcon(systemName: "sparkles", colors: [.purple, .indigo], size: 56)
                    .padding(.top, 40)
                Text("What do you need?")
                    .font(.title3.weight(.semibold))
                Text("Your coach can see your data and act on it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 10) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            sendMessage(suggestion)
                        } label: {
                            Text(suggestion)
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.pressable)
                        .disabled(isThinking)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                if isThinking {
                    thinkingIndicator
                        .padding(.top, 8)
                }
            }
        }
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(store.coachMessages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    if isThinking {
                        thinkingIndicator
                            .id("thinking")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: store.coachMessages.count) {
                if let last = store.coachMessages.last {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: isThinking) {
                if isThinking {
                    withAnimation { proxy.scrollTo("thinking", anchor: .bottom) }
                }
            }
            .onAppear {
                if let last = store.coachMessages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var thinkingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text("Coach is thinking…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask your coach…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .focused($inputFocused)
                .disabled(isThinking)

            Button {
                sendMessage(draft)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(canSend ? AnyShapeStyle(Theme.gradient([.purple, .indigo])) : AnyShapeStyle(.tertiary))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var canSend: Bool {
        !isThinking && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Sending

    private func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isThinking else { return }

        Haptics.tap()
        errorText = nil
        draft = ""
        store.appendCoachMessage(CoachMessage(role: .user, text: trimmed))
        isThinking = true

        Task {
            do {
                let reply = try await CoachEngine.shared.send(
                    history: store.coachMessages,
                    context: store.coachContext(),
                    store: store
                )
                store.appendCoachMessage(
                    CoachMessage(role: .coach, text: reply.text, actions: reply.actions)
                )
                if !reply.actions.isEmpty {
                    Haptics.success()
                }
            } catch {
                errorText = error.localizedDescription
            }
            isThinking = false
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: CoachMessage

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
            Text(message.text)
                .font(.subheadline)
                .foregroundStyle(message.role == .user ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(bubbleBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            ForEach(message.actions, id: \.self) { action in
                Label(action, systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .padding(message.role == .user ? .leading : .trailing, 48)
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if message.role == .user {
            Theme.gradient([.purple, .indigo])
        } else {
            Color(.secondarySystemGroupedBackground)
        }
    }
}
