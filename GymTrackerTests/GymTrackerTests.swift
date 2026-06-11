import XCTest
@testable import GymTracker

final class GymTrackerTests: XCTestCase {

    // MARK: - Nutrition math

    func testFoodEntryScalesWithServings() {
        let food = Food(name: "Greek Yogurt", serving: "1 cup", calories: 150, protein: 20, carbs: 8, fat: 4)
        let entry = FoodEntry(meal: .breakfast, food: food, servings: 1.5)

        XCTAssertEqual(entry.calories, 225, accuracy: 0.001)
        XCTAssertEqual(entry.protein, 30, accuracy: 0.001)
        XCTAssertEqual(entry.carbs, 12, accuracy: 0.001)
        XCTAssertEqual(entry.fat, 6, accuracy: 0.001)
    }

    // MARK: - Workout math

    func testWorkoutVolumeCountsOnlyCompletedSets() {
        let exercise = WorkoutExercise(name: "Bench Press", sets: [
            WorkoutSet(weight: 135, reps: 10, completed: true),
            WorkoutSet(weight: 155, reps: 8, completed: true),
            WorkoutSet(weight: 185, reps: 5, completed: false)
        ])
        let workout = Workout(name: "Push", date: Date(), duration: 3600, exercises: [exercise])

        XCTAssertEqual(workout.totalVolume, 135 * 10 + 155 * 8, accuracy: 0.001)
        XCTAssertEqual(workout.completedSetCount, 2)
        XCTAssertEqual(exercise.topWeight, 155)
    }

    // MARK: - Formatting

    func testCleanNumberFormatting() {
        XCTAssertEqual(185.0.clean, "185")
        XCTAssertEqual(187.5.clean, "187.5")
        XCTAssertEqual((45.0 * 60).shortDuration, "45m")
        XCTAssertEqual((75.0 * 60).shortDuration, "1h 15m")
    }
}
