import Foundation

class WorkoutParser {
    enum ParserError: Error {
        case invalidFormat
        case noExercisesFound
    }

    static func parse(markdown: String) throws -> [WorkoutPlan] {
        // Try markdown format first
        if let plans = try? parseMarkdownFormat(markdown), !plans.isEmpty {
            return plans
        }

        // Try simple line format (exercise name followed by numbers)
        if let plans = try? parseSimpleFormat(markdown), !plans.isEmpty {
            return plans
        }

        throw ParserError.noExercisesFound
    }

    // Original markdown format parser
    private static func parseMarkdownFormat(_ markdown: String) throws -> [WorkoutPlan] {
        let lines = markdown.components(separatedBy: .newlines)
        var plans: [WorkoutPlan] = []
        var currentPlan: (name: String, exercises: [Exercise])? = nil
        var currentExercise: (name: String, sets: Int?, reps: String?, tempo: String?, notes: String?)? = nil

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Workout name (# Header)
            if trimmed.hasPrefix("# ") {
                // Save previous plan if exists
                if let plan = currentPlan, !plan.exercises.isEmpty {
                    plans.append(WorkoutPlan(name: plan.name, exercises: plan.exercises))
                }
                currentPlan = (name: String(trimmed.dropFirst(2)), exercises: [])
                currentExercise = nil
            }
            // Exercise name (## Header)
            else if trimmed.hasPrefix("## ") {
                // Save previous exercise if exists
                if let exercise = currentExercise,
                   let sets = exercise.sets,
                   let reps = exercise.reps,
                   var plan = currentPlan {
                    let newExercise = Exercise(
                        name: exercise.name,
                        targetSets: sets,
                        targetReps: reps,
                        tempo: exercise.tempo,
                        notes: exercise.notes
                    )
                    plan.exercises.append(newExercise)
                    currentPlan = plan
                }
                currentExercise = (name: String(trimmed.dropFirst(3)), sets: nil, reps: nil, tempo: nil, notes: nil)
            }
            // Sets
            else if trimmed.lowercased().hasPrefix("sets:") {
                if var exercise = currentExercise {
                    let value = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
                    exercise.sets = Int(value)
                    currentExercise = exercise
                }
            }
            // Reps
            else if trimmed.lowercased().hasPrefix("reps:") {
                if var exercise = currentExercise {
                    let value = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
                    exercise.reps = value
                    currentExercise = exercise
                }
            }
            // Tempo
            else if trimmed.lowercased().hasPrefix("tempo:") {
                if var exercise = currentExercise {
                    let value = trimmed.dropFirst(6).trimmingCharacters(in: .whitespaces)
                    exercise.tempo = value
                    currentExercise = exercise
                }
            }
            // Notes
            else if trimmed.lowercased().hasPrefix("notes:") {
                if var exercise = currentExercise {
                    let value = trimmed.dropFirst(6).trimmingCharacters(in: .whitespaces)
                    exercise.notes = value
                    currentExercise = exercise
                }
            }
        }

        // Save last exercise and plan
        if let exercise = currentExercise,
           let sets = exercise.sets,
           let reps = exercise.reps,
           var plan = currentPlan {
            let newExercise = Exercise(
                name: exercise.name,
                targetSets: sets,
                targetReps: reps,
                tempo: exercise.tempo,
                notes: exercise.notes
            )
            plan.exercises.append(newExercise)
            currentPlan = plan
        }

        if let plan = currentPlan, !plan.exercises.isEmpty {
            plans.append(WorkoutPlan(name: plan.name, exercises: plan.exercises))
        }

        guard !plans.isEmpty else {
            throw ParserError.noExercisesFound
        }

        return plans
    }

    // Simple format: "Exercise Name [sets] [reps] [optional notes]"
    // Examples:
    // "Bench Press 4 8-10"
    // "Hip Abductor Machine 2 20 1-1-1-0"
    // "Squat 3 10-12 2-1-2-0 Start at bottom"
    //
    // Also supports multi-workout plans with "Day X: Description" markers:
    // "Day 1: Push"
    // "Day 2: Pull"
    //
    // Superset support:
    // "Superset:" or "SS:" followed by exercises on next lines
    // Or inline: "Bench Press / Rows 3 10"
    private static func parseSimpleFormat(_ text: String) throws -> [WorkoutPlan] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var plans: [WorkoutPlan] = []
        var currentExercises: [Exercise] = []
        var currentPlanName = "Imported Workout"
        var hasMultipleDays = false

        // Superset tracking
        var inSuperset = false
        var currentSupersetId: String? = nil
        var supersetExerciseCount = 0
        var supersetCounter = 0

        // Check if text contains Day markers
        let dayPattern = try? NSRegularExpression(pattern: "^Day\\s+\\d+", options: .caseInsensitive)
        let supersetHeaderPattern = try? NSRegularExpression(pattern: "^(superset|ss)\\s*:", options: .caseInsensitive)

        // Pattern to detect A1/A2/B1/B2 style exercise labels
        let exerciseLabelPattern = try? NSRegularExpression(pattern: "^([A-Za-z])(\\d+)[.:\\s]", options: [])

        // Track exercise labels for superset grouping (A1, A2 -> same superset)
        var labelSupersetMap: [String: String] = [:] // "A" -> "superset-1", "B" -> "superset-2"

        for line in lines {
            // Skip lines that look like headers or descriptions
            if line.lowercased().contains("exercise") && line.lowercased().contains("sets") {
                continue
            }

            // Skip instruction lines (contain keywords like "perform", "followed by", "repeat", "rounds", "rest")
            let lowerLine = line.lowercased()
            if lowerLine.contains("perform") || lowerLine.contains("followed by") ||
               lowerLine.contains("repeat") || lowerLine.contains("rounds") ||
               (lowerLine.contains("rest") && lowerLine.contains("second")) {
                continue
            }

            // Check for "Day X: Description" pattern
            if let dayPattern = dayPattern,
               dayPattern.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) != nil {
                hasMultipleDays = true
                inSuperset = false
                currentSupersetId = nil

                // Save previous workout if it has exercises
                if !currentExercises.isEmpty {
                    plans.append(WorkoutPlan(name: currentPlanName, exercises: currentExercises))
                    currentExercises = []
                }

                // Extract the workout name from the Day line
                currentPlanName = extractDayName(from: line)
                continue
            }

            // Check for superset header ("Superset:" or "SS:")
            if let supersetHeaderPattern = supersetHeaderPattern,
               supersetHeaderPattern.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) != nil {
                supersetCounter += 1
                currentSupersetId = "superset-\(supersetCounter)"
                inSuperset = true
                supersetExerciseCount = 0
                continue
            }

            // Try to extract workout name from lines that look like titles (only if no Day markers found yet)
            if !hasMultipleDays && line.count < 50 && !line.contains(":") && currentExercises.isEmpty && plans.isEmpty {
                let components = line.components(separatedBy: .whitespaces)
                // If line has few words and no numbers, might be a title
                if components.count <= 5 && !components.contains(where: { Int($0) != nil }) {
                    currentPlanName = line
                    continue
                }
            }

            // Check for inline superset format: "Exercise1 / Exercise2 sets reps"
            if let supersetExercises = parseInlineSupersetLine(line) {
                supersetCounter += 1
                let ssId = "superset-\(supersetCounter)"
                for var exercise in supersetExercises {
                    exercise = Exercise(
                        id: exercise.id,
                        name: exercise.name,
                        targetSets: exercise.targetSets,
                        targetReps: exercise.targetReps,
                        notes: exercise.notes,
                        supersetId: ssId
                    )
                    currentExercises.append(exercise)
                }
                continue
            }

            // Check for A1/A2/B1/B2 style labels
            var exerciseLabel: String? = nil
            var lineWithoutLabel = line
            if let exerciseLabelPattern = exerciseLabelPattern,
               let match = exerciseLabelPattern.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) {
                if let letterRange = Range(match.range(at: 1), in: line) {
                    exerciseLabel = String(line[letterRange]).uppercased()
                }
                // Remove the label prefix from the line for parsing
                if let fullMatchRange = Range(match.range, in: line) {
                    lineWithoutLabel = String(line[fullMatchRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                }
            }

            // Parse regular exercise line
            if var exercise = parseExerciseLine(lineWithoutLabel) {
                // Check for A1/A2 style superset grouping
                if let label = exerciseLabel {
                    if let existingSupersetId = labelSupersetMap[label] {
                        // Use existing superset ID for this label group
                        exercise = Exercise(
                            id: exercise.id,
                            name: exercise.name,
                            targetSets: exercise.targetSets,
                            targetReps: exercise.targetReps,
                            notes: exercise.notes,
                            supersetId: existingSupersetId
                        )
                    } else {
                        // Create new superset ID for this label group
                        supersetCounter += 1
                        let ssId = "superset-\(supersetCounter)"
                        labelSupersetMap[label] = ssId
                        exercise = Exercise(
                            id: exercise.id,
                            name: exercise.name,
                            targetSets: exercise.targetSets,
                            targetReps: exercise.targetReps,
                            notes: exercise.notes,
                            supersetId: ssId
                        )
                    }
                }
                // If we're in a superset block (from "Superset:" header), assign the superset ID
                else if inSuperset, let ssId = currentSupersetId {
                    exercise = Exercise(
                        id: exercise.id,
                        name: exercise.name,
                        targetSets: exercise.targetSets,
                        targetReps: exercise.targetReps,
                        notes: exercise.notes,
                        supersetId: ssId
                    )
                    supersetExerciseCount += 1

                    // End superset after 2 exercises (typical superset)
                    if supersetExerciseCount >= 2 {
                        inSuperset = false
                        currentSupersetId = nil
                    }
                }
                currentExercises.append(exercise)
            } else if inSuperset && line.isEmpty {
                // Empty line ends superset block
                inSuperset = false
                currentSupersetId = nil
            }
        }

        // Save the last workout
        if !currentExercises.isEmpty {
            plans.append(WorkoutPlan(name: currentPlanName, exercises: currentExercises))
        }

        guard !plans.isEmpty else {
            throw ParserError.noExercisesFound
        }

        return plans
    }

    // Parse inline superset: "Exercise1 / Exercise2 3 10" or "Exercise1 / Exercise2 3 10, 8 3-1-2-0"
    private static func parseInlineSupersetLine(_ line: String) -> [Exercise]? {
        // Must contain "/" to be an inline superset
        guard line.contains("/") else { return nil }

        // Split by "/" but be careful - we need to identify exercise names vs sets/reps
        let parts = line.components(separatedBy: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 2 else { return nil }

        // Try to parse as "Exercise1 / Exercise2 sets reps"
        let firstExerciseName = parts[0]
        guard !firstExerciseName.isEmpty else { return nil }

        // Check if first part has numbers (would be a regular exercise, not superset)
        let firstComponents = firstExerciseName.components(separatedBy: .whitespaces)
        if firstComponents.contains(where: { Int($0) != nil }) {
            return nil // First part has numbers, not a superset format
        }

        // The last part should contain "Exercise2 sets reps" or just "Exercise2" with shared sets/reps
        let lastPart = parts[parts.count - 1]
        let lastComponents = lastPart.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        // Find where the numbers start in the last part
        guard let firstNumberIndex = lastComponents.firstIndex(where: { Int($0) != nil }) else {
            return nil // No sets/reps found
        }

        // Extract second exercise name
        let secondExerciseName = lastComponents[0..<firstNumberIndex].joined(separator: " ")
        guard !secondExerciseName.isEmpty else { return nil }

        // Extract sets
        guard let sets = Int(lastComponents[firstNumberIndex]),
              firstNumberIndex + 1 < lastComponents.count else {
            return nil
        }

        // Extract reps - collect all rep components until we hit tempo
        var repsParts: [String] = []
        var currentIndex = firstNumberIndex + 1

        while currentIndex < lastComponents.count {
            let component = lastComponents[currentIndex]

            if isTempoPattern(component) {
                break
            }

            if isRepComponent(component) {
                repsParts.append(component)
                currentIndex += 1
            } else {
                break
            }
        }

        guard !repsParts.isEmpty else { return nil }
        let reps = repsParts.joined(separator: " ").replacingOccurrences(of: " ,", with: ",").replacingOccurrences(of: ", ", with: ",")

        // Check for tempo after reps
        var tempo: String? = nil
        if currentIndex < lastComponents.count && isTempoPattern(lastComponents[currentIndex]) {
            tempo = lastComponents[currentIndex]
        }

        // Create both exercises with same sets/reps/tempo
        let exercise1 = Exercise(name: firstExerciseName, targetSets: sets, targetReps: reps, tempo: tempo)
        let exercise2 = Exercise(name: secondExerciseName, targetSets: sets, targetReps: reps, tempo: tempo)

        return [exercise1, exercise2]
    }

    // Extract a clean name from "Day X: Description" or "Day X - Description" lines
    private static func extractDayName(from line: String) -> String {
        // Try to find separator (: or -)
        if let colonIndex = line.firstIndex(of: ":") {
            let afterColon = line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)
            if !afterColon.isEmpty {
                return afterColon
            }
        }

        if let dashIndex = line.firstIndex(of: "-") {
            let afterDash = line[line.index(after: dashIndex)...].trimmingCharacters(in: .whitespaces)
            if !afterDash.isEmpty {
                return afterDash
            }
        }

        // If no separator or nothing after it, use the whole line
        return line
    }

    private static func parseExerciseLine(_ line: String) -> Exercise? {
        // Split line into components
        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        guard components.count >= 3 else { return nil }

        // Find first number (this should be sets)
        guard let firstNumberIndex = components.firstIndex(where: { Int($0) != nil }) else {
            return nil
        }

        // Everything before first number is exercise name
        let nameParts = components[0..<firstNumberIndex]
        let name = nameParts.joined(separator: " ")

        guard !name.isEmpty else { return nil }

        // Extract sets
        guard let sets = Int(components[firstNumberIndex]) else { return nil }

        // Extract reps - collect all components that look like reps until we hit tempo or notes
        // Reps can be: "10", "8-10", "15,", "12", etc. (comma-separated reps get split)
        guard firstNumberIndex + 1 < components.count else { return nil }

        var repsParts: [String] = []
        var currentIndex = firstNumberIndex + 1

        while currentIndex < components.count {
            let component = components[currentIndex]

            // Check if this is a tempo pattern - if so, stop collecting reps
            if isTempoPattern(component) {
                break
            }

            // Check if this looks like a rep value (number, possibly with comma or dash)
            if isRepComponent(component) {
                repsParts.append(component)
                currentIndex += 1
            } else {
                // Not a rep component, stop collecting
                break
            }
        }

        guard !repsParts.isEmpty else { return nil }

        // Join reps parts and clean up spacing around commas
        let reps = repsParts.joined(separator: " ").replacingOccurrences(of: " ,", with: ",").replacingOccurrences(of: ", ", with: ",")

        // Check for tempo
        var tempo: String? = nil
        if currentIndex < components.count && isTempoPattern(components[currentIndex]) {
            tempo = components[currentIndex]
            currentIndex += 1
        }

        // Everything else is notes
        var notes: String? = nil
        if currentIndex < components.count {
            notes = components[currentIndex...].joined(separator: " ")
        }

        return Exercise(
            name: name,
            targetSets: sets,
            targetReps: reps,
            tempo: tempo,
            notes: notes
        )
    }

    // Check if a component looks like part of a rep specification
    private static func isRepComponent(_ str: String) -> Bool {
        // Remove trailing comma for checking
        let cleaned = str.trimmingCharacters(in: CharacterSet(charactersIn: ","))

        // Check if it's a number or a range like "8-10"
        if Int(cleaned) != nil {
            return true
        }

        // Check for range pattern like "8-10"
        let rangeParts = cleaned.components(separatedBy: "-")
        if rangeParts.count == 2,
           Int(rangeParts[0]) != nil,
           Int(rangeParts[1]) != nil {
            return true
        }

        return false
    }

    // Check if string matches tempo pattern: "3-1-2-0", "3010", "2-0-2-0", etc.
    private static func isTempoPattern(_ str: String) -> Bool {
        // Pattern 1: 4 digits with dashes (e.g., "3-1-2-0")
        let dashPattern = try? NSRegularExpression(pattern: "^\\d-\\d-\\d-\\d$", options: [])
        if let dashPattern = dashPattern,
           dashPattern.firstMatch(in: str, options: [], range: NSRange(str.startIndex..., in: str)) != nil {
            return true
        }

        // Pattern 2: 4 consecutive digits (e.g., "3010")
        let digitPattern = try? NSRegularExpression(pattern: "^\\d{4}$", options: [])
        if let digitPattern = digitPattern,
           digitPattern.firstMatch(in: str, options: [], range: NSRange(str.startIndex..., in: str)) != nil {
            return true
        }

        return false
    }

    static func exampleWorkout() -> String {
        """
        # Push Day A

        ## Bench Press
        Sets: 4
        Reps: 6-8
        Notes: Pause at bottom

        ## Overhead Press
        Sets: 3
        Reps: 8-10

        ## Incline Dumbbell Press
        Sets: 3
        Reps: 10-12
        """
    }
}
