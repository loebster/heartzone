# HeartZone

A watchOS app that gives haptic feedback during cycling workouts based on whether your heart rate is inside, above, or below a configured target zone.

**Silence inside the zone. Vibration outside.**

## How it works

### Simple Mode
1. Set your target heart rate zone (min/max) using the Digital Crown
2. Tap Start to begin a cycling workout
3. Ride — the app monitors your heart rate in real time
4. **Above zone:** 3 haptic taps, repeating every 15 seconds
5. **Below zone:** 1 haptic tap, repeating every 60 seconds
6. **In zone:** silence

### Plan Mode
1. Tap Plan on the start screen
2. Choose a preset (Tempo 30 min, Intervall 4×4 min)
3. Adjust HR zones per phase with the Digital Crown
4. Start Plan — the app auto-advances through timed phases and updates zones accordingly

The zone state machine uses a 5-second tolerance window before triggering warnings, filtering out sensor noise and brief fluctuations.

## Requirements

- Apple Watch with watchOS 10+
- Xcode 15+
- No third-party dependencies — pure Apple frameworks (HealthKit, SwiftUI, WatchKit)

## Setup

1. Open `Heartzone.xcodeproj` in Xcode
2. Select your Apple Watch as the run destination
3. Build and run (Personal Team signing is fine)
4. Grant HealthKit permissions when prompted
5. Enable **Silent Mode** on your Apple Watch for vibration-only feedback

## Features

- Crown-based min/max heart rate configuration (persisted across launches)
- Live heart rate display with color-coded zone indicator (blue/green/red)
- Gauge visualization showing HR position relative to zone boundaries
- Plan mode with preset workout templates (Tempo, Intervall) and Crown-editable phases
- Auto-advancing timed phases with manual "Next" for open-ended phases
- HKWorkoutSession with outdoor cycling activity type
- Workout saved to Apple Health on stop
- Startup haptic pattern ("tick, tick, tick, go!")
- Graceful handling of denied HealthKit permissions

## Architecture

Watch-only app — no iPhone companion. Three Swift files:

- `WorkoutManager.swift` — HealthKit session, zone state machine, haptic patterns, plan/phase logic, workout plan presets
- `ContentView.swift` — all views: start screen, workout view with gauge, plan list, plan detail, phase editor, SwiftUI previews
- `HeartzoneApp.swift` — app entry point

## License

Personal project. No license specified.
