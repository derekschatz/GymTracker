# GymTracker

A native iOS and watchOS app for tracking weightlifting workouts with real-time sync between your iPhone and Apple Watch.

## Features

### iOS App
- **Import Workouts**: Parse workout plans from text with support for:
  - Multi-day workout programs (Day 1, Day 2, etc.)
  - Supersets (A1/A2 notation, inline format, or "Superset:" headers)
  - Variable reps per set (e.g., "10, 8, 8, 6")
  - Tempo notation (e.g., "3-1-1-0")
- **Active Workout Tracking**:
  - Log weight and reps for each set
  - Rest timer with customizable presets (1m, 1:30, 2m, 3m)
  - Visual progress through exercises
  - Superset grouping with exercises displayed together
- **Workout History**: Track completed sessions with volume calculations
- **HealthKit Integration**: Sync workouts to Apple Health
- **Previous Weight Tracking**: See what you lifted last time for each exercise

### Watch App
- **Companion App**: Full workout tracking from your wrist
- **Digital Crown Support**: Adjust weight using the crown (±1 lb) or buttons (±5 lbs)
- **Real-time Sync**:
  - Set completions sync instantly between phone and watch
  - Exercise navigation syncs both ways
  - Edit or delete sets from either device
- **Rest Timer**: Built-in countdown timer with quick-add options
- **Set History**: Long-press exercise name to view/edit logged sets

## Workout Import Format

The parser supports flexible workout formats:

```
Day 1: Push
Barbell Bench Press 4 10, 8, 8, 6 3-1-1-0 Add weight each set
Overhead Press 3 8-10 2-0-2-0
Incline Dumbbell Press 3 10-12

Day 2: Pull
A1. Barbell Row 4 8
A2. Face Pulls 4 15
Lat Pulldown 3 10-12
```

### Supported Patterns
- **Sets & Reps**: `Exercise Name [sets] [reps]`
- **Variable Reps**: `Exercise 4 10, 8, 8, 6` (different reps per set)
- **Rep Ranges**: `Exercise 3 8-10`
- **Tempo**: `Exercise 3 10 3-1-1-0` or `Exercise 3 10 3010`
- **Supersets**:
  - `A1. Exercise / A2. Exercise`
  - `Exercise1 / Exercise2 3 10`
  - `Superset:` header followed by exercises
- **Notes**: Any text after tempo is captured as notes

## Requirements

- iOS 17.0+
- watchOS 10.0+
- Xcode 15.0+

## Installation

1. Clone the repository
2. Open `GymTracker.xcodeproj` in Xcode
3. Select your development team in Signing & Capabilities
4. Build and run on your device

## Architecture

- **SwiftUI**: Native UI framework for both iOS and watchOS
- **WatchConnectivity**: Real-time communication between iPhone and Apple Watch
- **HealthKit**: Integration with Apple Health for workout logging
- **Codable**: JSON-based data persistence using UserDefaults

## Project Structure

```
GymTracker/
├── GymTracker/                    # iOS App
│   ├── GymTrackerApp.swift        # App entry point
│   ├── ContentView.swift          # Main view with workout list
│   ├── ActiveWorkoutView.swift    # Active workout session UI
│   ├── ImporterView.swift         # Workout import interface
│   ├── Models.swift               # Data models
│   ├── DataManager.swift          # Data persistence
│   ├── WorkoutParser.swift        # Workout text parser
│   ├── PhoneToWatchManager.swift  # Watch communication
│   └── HealthKitManager.swift     # HealthKit integration
│
└── GymTrackerWatch Watch App/     # watchOS App
    ├── GymTrackerWatchApp.swift   # Watch app entry point
    ├── WatchContentView.swift     # Watch main view
    ├── WatchWorkoutView.swift     # Watch workout UI
    └── WatchWorkoutManager.swift  # Watch state & phone communication
```

## License

MIT License
