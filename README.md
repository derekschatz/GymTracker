# GymTracker

A simple, reliable fitness app for iOS and Apple Watch. Track your workouts,
your food, and your body weight in one place — without the maintenance burden
of bigger fitness apps.

## Philosophy

- **Simple over feature-intensive.** Three tabs. Every common action is one
  or two taps.
- **Custom-first logging.** Create your own foods and exercises in seconds;
  they're saved to your library and your recents for one-tap re-logging.
- **Reliable.** All data is plain JSON stored on-device with atomic writes.
  An in-progress workout survives a crash or force-quit. No accounts, no
  network, no sync to break.

## The Three Tabs

### Today
Your fitness portfolio at a glance:
- Calorie ring (eaten vs. goal) with protein/carb/fat totals
- Today's training: start, resume, or review your workout
- Body weight: one-tap logging with a trend chart

### Nutrition
- Daily log organized by meal (breakfast, lunch, dinner, snacks)
- Create custom foods (name, serving, calories, macros) — saved to your
  library forever
- Recents surface what you actually eat for one-tap logging
- Flip back through previous days with the date arrows

### Workout
- Start an empty workout or launch a saved routine in one tap
- Log sets (weight × reps) with a checkmark; weights prefill from the last
  time you did the exercise
- Built-in rest timer (synced to the watch)
- Save any finished workout as a routine
- Exercise library with custom exercises and progress charts
- Full workout history

## Apple Watch

The companion watch app tracks the active workout from your wrist:
- Set completions sync instantly both ways
- Adjust weight with the Digital Crown
- Rest timer stays in sync with the phone

## Apple Health

Finished workouts are saved to Apple Health automatically (best-effort —
a Health permission issue never blocks the app).

## Data & Reliability

- Models are plain `Codable` structs (`Models.swift`)
- A single `AppStore` owns all state and persists each collection as a JSON
  file in Application Support with atomic writes (`AppStore.swift`)
- Data from the previous version of the app (workout plans and history) is
  migrated automatically on first launch

## Requirements

- iOS 26.0+ / watchOS 26.2+
- Xcode 16+

## Project Structure

```
GymTracker/
├── GymTracker/                    # iOS App
│   ├── GymTrackerApp.swift        # App entry point
│   ├── ContentView.swift          # Root tab view
│   ├── TodayView.swift            # Dashboard, weight log, settings
│   ├── NutritionView.swift        # Daily food log
│   ├── AddFoodView.swift          # Food picker, custom foods, library
│   ├── WorkoutView.swift          # Workout home, routines, history, progress
│   ├── ActiveWorkoutView.swift    # Live workout session
│   ├── Models.swift               # All data models
│   ├── AppStore.swift             # State + JSON persistence + migration
│   ├── PhoneToWatchManager.swift  # Watch sync
│   └── HealthKitManager.swift     # Apple Health integration
│
└── GymTrackerWatch Watch App/     # watchOS App
```

## License

MIT License
