# HeartZone

A watchOS app that gives haptic feedback during cycling workouts based on whether your heart rate is inside, above, or below a configured target zone.

**Silence inside the zone. Vibration outside.**

## How it works

1. Set your target heart rate zone (min/max) using the Digital Crown
2. Tap Start to begin a cycling workout
3. Ride — the app monitors your heart rate in real time
4. **Above zone:** 3 haptic taps, repeating every 15 seconds
5. **Below zone:** 1 haptic tap, repeating every 60 seconds
6. **In zone:** silence

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

## Features (v0.1)

- Crown-based min/max heart rate configuration (persisted across launches)
- Live heart rate display with color-coded zone indicator
- HKWorkoutSession with outdoor cycling activity type
- Workout saved to Apple Health on stop
- Startup haptic pattern ("tick, tick, tick, go!")
- Pattern test screen for trying haptics outside a workout
- Graceful handling of denied HealthKit permissions

## Architecture

Watch-only app — no iPhone companion. Three Swift files:

- `WorkoutManager.swift` — HealthKit session, zone state machine, haptic patterns
- `ContentView.swift` — configuration view, workout view, pattern test view
- `HeartzoneApp.swift` — app entry point

## License

Personal project. No license specified.
