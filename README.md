# GymTracker

A fitness app with an actual coach. Track your workouts, food, and body
weight in one simple, reliable app — and talk to a coach that knows all of
it, builds your plans for you, and tells you the one thing to do today.

## Why a coach?

Fitness has an adherence crisis, not an information crisis: most people
abandon fitness apps within 90 days, usually right after missed workouts or
a plateau. What works is a personal trainer — accountability plus
adaptation — at $400+/month. GymTracker's coach closes that gap:

- **It knows you.** Every chat includes your real data: lifts, food log,
  weight trend, and training consistency.
- **It acts.** The coach writes and updates your routines and sets your
  calorie/protein targets itself, via tools — not advice you have to
  transcribe.
- **One thing today.** A daily brief kills choice paralysis: one action,
  one encouraging number.
- **Comeback-first.** No streaks, no guilt. Missed time triggers
  replanning, smaller — because the day you fall off is the day every
  other app loses you.

The coach is powered by the Claude API (bring your own key, stored in the
Keychain). Everything else works fully offline.

## Philosophy

- **Simple over feature-intensive.** Four tabs. Every common action is one
  or two taps.
- **Custom-first logging.** Create your own foods and exercises in seconds;
  they're saved to your library and your recents for one-tap re-logging.
- **Reliable.** All data is plain JSON stored on-device with atomic writes.
  An in-progress workout survives a crash or force-quit. No accounts, no
  sync to break; the network is used only for coach chats.

## The Four Tabs

### Today
Your fitness portfolio at a glance:
- The coach's daily brief — your one thing today
- Calorie ring (eaten vs. goal) with protein/carb/fat totals
- Today's training: start, resume, or review your workout
- Body weight: one-tap logging with a trend chart

### Coach
- Chat with a coach that sees your full data and history
- Asks it to build a plan → it saves real routines into the app
- Asks for targets → it sets your calorie/protein goals
- Designed for comebacks: tell it you've been off for two weeks and it
  rebuilds the plan smaller, no lectures

### Nutrition
- Daily log organized by meal (breakfast, lunch, dinner, snacks)
- **Describe it**: type "2 eggs, toast with butter, coffee" and the coach
  estimates calories and macros and logs it as one entry
- **One-tap quick-add** on every food row — log a whole meal in seconds
- **Same as yesterday**: empty meals offer a one-tap copy of yesterday's
- Create custom foods (name, serving, calories, macros) — saved to your
  library forever; recents surface what you actually eat
- Flip back through previous days with the date arrows

### Workout
- Start an empty workout or launch a saved routine in one tap
- Log sets (weight × reps) with a checkmark; weights prefill from the last
  time you did the exercise
- Built-in rest timer (synced to the watch)
- Save any finished workout as a routine
- **Cardio quick-log**: activity → minutes → optional distance, in ten
  seconds — synced to Apple Health with the right activity type
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
│   ├── CoachView.swift            # Coach chat
│   ├── CoachEngine.swift          # Claude API client + coach tools
│   ├── CoachModels.swift          # Profile, messages, daily brief
│   ├── OnboardingView.swift       # 30-second first-launch setup
│   ├── Models.swift               # All data models
│   ├── AppStore.swift             # State + JSON persistence + migration
│   ├── DesignSystem.swift         # Theme, components, haptics
│   ├── Keychain.swift             # API key storage
│   ├── PhoneToWatchManager.swift  # Watch sync
│   └── HealthKitManager.swift     # Apple Health integration
│
└── GymTrackerWatch Watch App/     # watchOS App
```

## License

MIT License
