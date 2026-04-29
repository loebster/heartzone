# HeartZone — Specification v0.1

## Purpose

HeartZone is a watchOS app that gives haptic feedback during a cycling workout based on whether the user's current heart rate is inside, above, or below a configured target zone. The goal is **low-involvement training**: the cyclist focuses on the road, the watch communicates zone status entirely through wrist haptics. No need to look at the screen.

The app fills a gap in Apple's built-in functionality: Apple's heart rate zone alerts only fire on zone exit with a single, undifferentiated haptic. HeartZone gives **directional** feedback (too low vs. too high) through distinct haptic patterns.

## Target Platform

- **watchOS 10 or newer**
- **Apple Watch Series 6 or newer**
- **Independent watch app** (no iPhone companion required in v0.1)
- **Language:** English UI

## Core Concept

> Silence is success.

When the user is inside the target heart rate zone, the watch is silent. Haptic feedback fires only when the user leaves the zone, and the pattern indicates the direction.

## Haptic Patterns

| State | Pattern | Subjective feel | Implementation hint |
|---|---|---|---|
| Inside zone | Silence | "all good" | No action |
| Below minimum | One long, slow pulse | "sluggish — like you" | Two `.directionDown` haptics in rapid succession to feel like one extended pulse |
| Above maximum | Three short, fast pulses | "hectic — like you" | Three `.notification` or `.click` haptics with ~150ms gap |
| Re-entry into zone | Short — long — short | "okay, you're good" | `.click` + `.directionDown` + `.click`, distinct from the warning patterns |

The haptic-mirroring philosophy is "embodied": the vibration mirrors the user's physiological state rather than instructing them what to do. A racing pulse feels hectic, so the haptic feels hectic. A slow pulse feels sluggish, so the haptic feels sluggish.

The exact tactile feel of these patterns must be tuned on real hardware during real rides. A pattern test screen (see below) supports this.

## Behavior

### Workout flow

1. User opens HeartZone on the watch.
2. Main screen shows current min/max heart rate and a Start button.
3. Min/max are adjustable via Digital Crown (tap value to focus, then turn crown).
4. Tap Start → app begins an `HKWorkoutSession` of type `.cycling`, location `.outdoor`.
5. During the workout: large, central display of current heart rate, with min/max shown for reference. Stop button.
6. Tap Stop → workout session ends, data is saved to Apple Health.

### Zone evaluation

- Sample the live heart rate from `HKLiveWorkoutBuilder`.
- Every second, evaluate current state against the configured zone.
- **Tolerance window:** Only after 5 consecutive seconds outside the zone does the warning cycle begin. Prevents false alarms from short spikes or sensor glitches.
- **Warning interval:** While outside the zone, fire the appropriate haptic pattern every 15 seconds.
- **Re-entry:** As soon as heart rate returns inside the zone, fire the re-entry confirmation pattern once, then silence.

### State machine (simplified)

```
[InZone]     <-- start
   |
   |  HR > max for >= 5s
   v
[AboveZone] -- every 15s: 3 short pulses
   |
   |  HR back in [min, max]
   v
[InZone (after re-entry)] -- fire short-long-short once

[InZone]
   |
   |  HR < min for >= 5s
   v
[BelowZone] -- every 15s: 1 long pulse
   |
   |  HR back in [min, max]
   v
[InZone (after re-entry)] -- fire short-long-short once
```

## Defaults

| Setting | Default | Range |
|---|---|---|
| Minimum HR | 130 bpm | 50–220 |
| Maximum HR | 150 bpm | 50–220 |
| Warning interval | 15 seconds | not user-configurable in v0.1 |
| Tolerance window | 5 seconds | not user-configurable in v0.1 |

Min/max persist across sessions via `@AppStorage` (UserDefaults).

## Required Capabilities & Permissions

- **HealthKit** entitlement
  - Read: Heart Rate (`HKQuantityType.heartRate`)
  - Share: Workouts (`HKWorkoutType`)
- **Background Mode:** Workout Processing (so the app keeps running with the screen off during a workout)
- **Info.plist entries:**
  - `NSHealthShareUsageDescription` — "HeartZone reads your heart rate during cycling workouts to provide zone-based haptic feedback."
  - `NSHealthUpdateUsageDescription` — "HeartZone saves your cycling workouts to the Health app."

## Tech Stack

| Component | Framework / API |
|---|---|
| UI | SwiftUI |
| Workout session | `HKWorkoutSession` + `HKLiveWorkoutBuilder` |
| Live heart rate | `HKLiveWorkoutBuilder` data delegate, sampling `HKQuantityType.heartRate` |
| Haptics | `WKInterfaceDevice.current().play(...)` with `.directionUp`, `.directionDown`, `.notification`, `.click` |
| Timing | `Timer.scheduledTimer` with 1-second tick for state evaluation; separate dispatch-after for haptic pattern sequences |
| Persistence | `@AppStorage` (UserDefaults) for min, max, last-used values |

## Edge Cases (explicit handling in v0.1)

1. **Sensor reports no data ("Measuring...")** → Display "—" instead of a number. Suspend zone evaluation until valid data resumes. No false warnings.
2. **User configures min ≥ max** → UI prevents this (when adjusting min via crown, it cannot exceed max-1; same for max).
3. **Watch display darkens during workout** → Workout continues in background due to Workout Processing entitlement. Haptics still fire.
4. **App force-quit during session** → Not handled in v0.1. User must restart manually. Workout data up to that point is lost.
5. **Low battery** → No special handling. Standard watchOS behavior applies.

## Pattern Test Screen

A separate screen accessible from the main view (button: "Test Patterns"). Three buttons:

- "Test: Below zone" → fires the long-slow pattern
- "Test: Above zone" → fires the three-fast-pulses pattern
- "Test: Re-entry" → fires the short-long-short pattern

Purpose: Allow the user to feel each pattern outside of a real workout, both for familiarization and for tuning. If a pattern feels wrong on real hardware, this is the iteration loop.

## Explicit non-goals for v0.1

The following are intentionally **not** included in v0.1, even if technically feasible:

- Interval training plans (phased zones over time)
- Multiple saved profiles (city ride, tempo, endurance)
- iPhone companion app
- Watchface complications
- Audio cues / voice feedback
- Custom history or statistics screens (Apple Health handles this)
- External Bluetooth heart rate sensors (e.g., chest straps)
- Sport types other than outdoor cycling
- Localization (English only)

These belong in `BACKLOG.md` for later consideration.

## Real-world testing approach

The success criteria for v0.1 cannot be evaluated in the simulator. The patterns must feel right at the wrist during actual cycling. Plan:

1. Build a working version that runs on the user's own watch (sideloaded via Personal Team).
2. Test on a 30–60 minute ride in a low-traffic area.
3. Note: which patterns work, which don't; whether 15s interval is right; whether 5s tolerance is right.
4. Iterate.

## Versioning

This is **v0.1**. The version number does not refer to App Store releases (there are none planned yet) but to internal milestones.

- **v0.1** — minimum viable feedback app, single zone, fixed timing, manual config on watch
- **v0.2** — open, will be informed by real-world testing of v0.1
