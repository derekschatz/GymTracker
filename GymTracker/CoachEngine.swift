import Foundation

enum CoachError: LocalizedError {
    case missingKey
    case badKey
    case rateLimited
    case overloaded
    case network
    case refused
    case server(String)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "Add your Claude API key in Settings to talk to your coach."
        case .badKey:
            return "Your API key was rejected. Check it in Settings."
        case .rateLimited:
            return "The coach is getting too many requests right now. Try again in a minute."
        case .overloaded:
            return "The coach service is briefly unavailable. Try again shortly."
        case .network:
            return "No connection. Your tracking still works offline — the coach needs internet."
        case .refused:
            return "The coach can't help with that one."
        case .server(let message):
            return message
        }
    }
}

/// The coach's brain: a thin client for the Claude API (`POST /v1/messages`)
/// with a manual tool-use loop so the coach can act on the app's data —
/// writing routines and setting targets — not just chat about them.
final class CoachEngine {
    static let shared = CoachEngine()
    private init() {}

    static let apiKeyKeychainKey = "anthropic_api_key"

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    /// Coach chat: Sonnet is the speed/intelligence sweet spot for short,
    /// data-grounded coaching turns with simple tool calls.
    private let chatModel = "claude-sonnet-4-6"

    /// Daily brief: a small summarize-the-context task that runs once per
    /// user per day — Haiku keeps the highest-volume call the cheapest.
    private let briefModel = "claude-haiku-4-5"

    var hasAPIKey: Bool {
        if let key = Keychain.load(Self.apiKeyKeychainKey), !key.isEmpty {
            return true
        }
        return false
    }

    // MARK: - System Prompt

    private static let systemPrompt = """
    You are Coach — the user's personal strength and nutrition coach inside GymTracker, \
    a simple, private fitness app. A CONTEXT section with the user's real data \
    (profile, goals, food log, workouts, body weight, consistency) follows this prompt. \
    Ground everything you say in that data.

    Coaching philosophy:
    - ONE THING TODAY. When the user asks what to do, give one clear action for today, \
    not a menu of options. Decision fatigue is why people quit.
    - COMEBACK-FIRST. Missed days are normal life, never failure. If the user has been \
    away, never guilt them and never mention streaks. Shrink the plan and restart \
    smaller than where they left off.
    - USE THEIR NUMBERS. Reference their actual lifts, calorie averages, and weight \
    trend. Prescribe specific weights, reps, and calorie targets, not vague advice.
    - ACT, DON'T LECTURE. When the user wants a plan created or targets changed, use \
    your tools to actually do it, then confirm in one short sentence. Prefer acting \
    over describing what they could do themselves.
    - PROGRESSIVE OVERLOAD. When they hit the top of a rep range across all sets, \
    suggest +5 lb on upper-body lifts and +10 lb on lower-body lifts.
    - SAFE DEFICITS ONLY. Never set calorie targets below 1,200 (women) / 1,500 (men); \
    aim for 0.5–1 lb of weight change per week. For pain, injury, or anything medical, \
    tell them to see a professional — you are a coach, not a doctor.

    Style: this is a chat on a phone. Keep replies to 2–6 short sentences. Plain \
    language, no headers, minimal lists. At most one question per reply, and only \
    when you genuinely need the answer. Be warm and direct, never preachy.
    """

    private static let tools: [[String: Any]] = [
        [
            "name": "save_routine",
            "description": "Create or update a workout routine in the user's app. If a routine with the same name already exists, it is replaced. Use this whenever the user wants a plan, program, or routine created or changed.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "name": ["type": "string", "description": "Routine name, e.g. 'Push Day'"],
                    "exercises": [
                        "type": "array",
                        "description": "Exercises in order",
                        "items": [
                            "type": "object",
                            "properties": [
                                "name": ["type": "string"],
                                "sets": ["type": "integer", "description": "Number of sets, 1-10"],
                                "reps": ["type": "integer", "description": "Target reps per set, 1-50"]
                            ],
                            "required": ["name", "sets", "reps"]
                        ]
                    ]
                ],
                "required": ["name", "exercises"]
            ]
        ],
        [
            "name": "delete_routine",
            "description": "Delete one of the user's saved workout routines by name. Only use when the user clearly asks to remove a routine.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "name": ["type": "string", "description": "Exact name of the routine to delete"]
                ],
                "required": ["name"]
            ]
        ],
        [
            "name": "set_goals",
            "description": "Set the user's daily calorie and/or protein targets in the app. Use when prescribing or adjusting nutrition targets.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "daily_calories": ["type": "number", "description": "Daily calorie target"],
                    "daily_protein": ["type": "number", "description": "Daily protein target in grams"]
                ],
                "required": []
            ]
        ]
    ]

    // MARK: - Chat

    struct Reply {
        var text: String
        var actions: [String]
    }

    /// Sends the conversation and executes any tool calls against the store.
    @MainActor
    func send(history: [CoachMessage], context: String, store: AppStore) async throws -> Reply {
        guard let key = Keychain.load(Self.apiKeyKeychainKey), !key.isEmpty else {
            throw CoachError.missingKey
        }

        // Conversation history as plain text turns; tool blocks are kept
        // verbatim only within this request's loop.
        var messages: [[String: Any]] = history.map { message -> [String: Any] in
            ["role": message.role == .user ? "user" : "assistant", "content": message.text]
        }

        var collectedText: [String] = []
        var actions: [String] = []

        for _ in 0..<5 {
            let body: [String: Any] = [
                "model": chatModel,
                "max_tokens": 4000,
                "thinking": ["type": "adaptive"],
                "system": [
                    ["type": "text", "text": Self.systemPrompt,
                     "cache_control": ["type": "ephemeral"]],
                    ["type": "text", "text": context]
                ],
                "tools": Self.tools,
                "messages": messages
            ]

            let response = try await request(body: body, key: key)
            let content = response["content"] as? [[String: Any]] ?? []
            let stopReason = response["stop_reason"] as? String

            if stopReason == "refusal" {
                throw CoachError.refused
            }

            for block in content where block["type"] as? String == "text" {
                if let text = block["text"] as? String,
                   !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    collectedText.append(text)
                }
            }

            guard stopReason == "tool_use" else { break }

            // Echo the assistant turn verbatim (preserves thinking blocks),
            // then answer every tool_use with a tool_result.
            messages.append(["role": "assistant", "content": content])

            var results: [[String: Any]] = []
            for block in content where block["type"] as? String == "tool_use" {
                let id = block["id"] as? String ?? ""
                let name = block["name"] as? String ?? ""
                let input = block["input"] as? [String: Any] ?? [:]
                let outcome = execute(tool: name, input: input, store: store)
                if let summary = outcome.summary {
                    actions.append(summary)
                }
                results.append([
                    "type": "tool_result",
                    "tool_use_id": id,
                    "content": outcome.result
                ])
            }
            messages.append(["role": "user", "content": results])
        }

        let text = collectedText.joined(separator: "\n\n")
        return Reply(
            text: text.isEmpty ? "Done." : text,
            actions: actions
        )
    }

    // MARK: - Daily Brief

    /// One short "here's your one thing today" — shares the cached system
    /// prompt with the chat.
    @MainActor
    func dailyBrief(context: String) async throws -> String {
        guard let key = Keychain.load(Self.apiKeyKeychainKey), !key.isEmpty else {
            throw CoachError.missingKey
        }

        let body: [String: Any] = [
            "model": briefModel,
            "max_tokens": 1000,
            "system": [
                ["type": "text", "text": Self.systemPrompt,
                 "cache_control": ["type": "ephemeral"]],
                ["type": "text", "text": context]
            ],
            "messages": [
                ["role": "user", "content": "Write my brief for today: 2-3 short sentences with the single most important action for me today and one encouraging, specific data point from my numbers. No greeting, no questions, no lists."]
            ]
        ]

        let response = try await request(body: body, key: key)

        if response["stop_reason"] as? String == "refusal" {
            throw CoachError.refused
        }

        let content = response["content"] as? [[String: Any]] ?? []
        let text = content
            .filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else { throw CoachError.network }
        return text
    }

    // MARK: - Tool Execution

    private struct ToolOutcome {
        var result: String
        var summary: String?
    }

    @MainActor
    private func execute(tool: String, input: [String: Any], store: AppStore) -> ToolOutcome {
        switch tool {
        case "save_routine":
            guard let name = input["name"] as? String,
                  let rawExercises = input["exercises"] as? [[String: Any]],
                  !rawExercises.isEmpty else {
                return ToolOutcome(result: "Error: missing routine name or exercises.")
            }
            let exercises = rawExercises.compactMap { item -> RoutineExercise? in
                guard let exerciseName = item["name"] as? String else { return nil }
                let sets = (item["sets"] as? NSNumber)?.intValue ?? 3
                let reps = (item["reps"] as? NSNumber)?.intValue ?? 10
                return RoutineExercise(
                    name: exerciseName,
                    setCount: min(max(sets, 1), 10),
                    reps: min(max(reps, 1), 50)
                )
            }
            guard !exercises.isEmpty else {
                return ToolOutcome(result: "Error: could not parse the exercises.")
            }
            for exercise in exercises {
                store.addExercise(named: exercise.name)
            }
            if let existing = store.routines.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                var updated = existing
                updated.name = name
                updated.exercises = exercises
                store.updateRoutine(updated)
                return ToolOutcome(
                    result: "Updated routine '\(name)' with \(exercises.count) exercises.",
                    summary: "Updated routine “\(name)”"
                )
            }
            store.addRoutine(Routine(name: name, exercises: exercises))
            return ToolOutcome(
                result: "Created routine '\(name)' with \(exercises.count) exercises.",
                summary: "Created routine “\(name)”"
            )

        case "delete_routine":
            guard let name = input["name"] as? String,
                  let routine = store.routines.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else {
                return ToolOutcome(result: "Error: no routine with that name.")
            }
            store.deleteRoutine(routine)
            return ToolOutcome(
                result: "Deleted routine '\(routine.name)'.",
                summary: "Deleted routine “\(routine.name)”"
            )

        case "set_goals":
            var goals = store.goals
            var changes: [String] = []
            if let calories = (input["daily_calories"] as? NSNumber)?.doubleValue, calories > 0 {
                goals.calories = calories
                changes.append("\(calories.clean) cal")
            }
            if let protein = (input["daily_protein"] as? NSNumber)?.doubleValue, protein > 0 {
                goals.protein = protein
                changes.append("\(protein.clean)g protein")
            }
            guard !changes.isEmpty else {
                return ToolOutcome(result: "Error: no targets provided.")
            }
            store.goals = goals
            let described = changes.joined(separator: ", ")
            return ToolOutcome(
                result: "Set daily targets: \(described).",
                summary: "Set targets: \(described)"
            )

        default:
            return ToolOutcome(result: "Error: unknown tool '\(tool)'.")
        }
    }

    // MARK: - HTTP

    private func request(body: [String: Any], key: String) async throws -> [String: Any] {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 180
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(key, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            throw CoachError.network
        }

        guard let http = response as? HTTPURLResponse else {
            throw CoachError.network
        }

        switch http.statusCode {
        case 200:
            break
        case 401, 403:
            throw CoachError.badKey
        case 429:
            throw CoachError.rateLimited
        case 500...599:
            throw CoachError.overloaded
        default:
            let message = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])
                .flatMap { $0["error"] as? [String: Any] }
                .flatMap { $0["message"] as? String }
            throw CoachError.server(message ?? "The coach hit an error (\(http.statusCode)). Try again.")
        }

        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw CoachError.network
        }
        return json
    }
}
