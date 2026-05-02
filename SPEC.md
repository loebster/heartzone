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

| State | Pattern | Repeat interval | Implementation |
|---|---|---|---|
| Inside zone | Silence | — | No action |
| Below minimum | 1× `.notification` | Every 60 seconds | Single strong tap |
| Above maximum | 3× `.notification` with 1s gaps | Every 15 seconds | Three taps, `Task.sleep(for: .seconds(1))` between each |
| Startup | 3× `.click` + 1× `.notification` | Once, at workout start | "Tick, tick, tick, go!" with 600ms gaps |
| Re-entry into zone | Silence | — | Cessation of warnings is the signal |

Both zone warnings use `.notification` (the strongest available `WKHapticType`). Differentiation is purely by count: 1 tap = below, 3 taps = above. The below-zone interval is longer (60s) because a frequent single tap becomes annoying at traffic lights or other brief stops. Above-zone is more urgent and repeats at 15s.

Note: watchOS does not support CoreHaptics. `WKInterfaceDevice.play()` produces fixed short impulses only — no control over duration or intensity. All patterns are designed around this constraint. `.notification` plays a system sound unless Silent Mode is enabled on the watch.

## Behavior

### Workout flow

1. User opens HeartZone on the watch.
2. Main screen shows current min/max heart rate and a Start button.
3. Min/max are adjustable via Digital Crown (tap value to focus, then turn crown).
4. Tap Start → app requests HealthKit authorization (shows alert if denied), then begins an `HKWorkoutSession` of type `.cycling`, location `.outdoor`. Startup haptic pattern fires.
5. During the workout: large, central display of current heart rate (color-coded: blue = below, green = in zone, red = above), zone state label, and min/max shown for reference. Stop button.
6. Tap Stop → workout session ends, data is saved to Apple Health.

### Zone evaluation

- Sample the live heart rate from `HKLiveWorkoutBuilder`.
- Every second, evaluate current state against the configured zone.
- **Tolerance window:** Only after 5 consecutive seconds outside the zone does the warning cycle begin. Prevents false alarms from short spikes or sensor glitches.
- **Warning interval:** Differs by zone — 15 seconds above zone, 60 seconds below zone. The first warning fires immediately when the tolerance window expires; repeats follow at the zone-specific interval.
- **Re-entry:** Silent. When heart rate returns inside the zone, warnings stop. The cessation of haptics is itself the signal.

### State machine (simplified)

```
[InZone]     <-- start (fires startup pattern)
   |
   |  HR > max for >= 5s
   v
[AboveZone] -- every 15s: 3× notification
   |
   |  HR back in [min, max]
   v
[InZone] -- silent

[InZone]
   |
   |  HR < min for >= 5s
   v
[BelowZone] -- every 60s: 1× notification
   |
   |  HR back in [min, max]
   v
[InZone] -- silent
```

## Defaults

| Setting | Default | Range |
|---|---|---|
| Minimum HR | 130 bpm | 50–220 |
| Maximum HR | 150 bpm | 50–220 |
| Warning interval (above zone) | 15 seconds | not user-configurable in v0.1 |
| Warning interval (below zone) | 60 seconds | not user-configurable in v0.1 |
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
| Haptics | `WKInterfaceDevice.current().play(...)` with `.notification` and `.click` |
| Timing | `Timer.scheduledTimer` with 1-second tick for state evaluation; `Task.sleep` for haptic pattern sequences |
| Persistence | `@AppStorage` (UserDefaults) for min, max, last-used values |

## Edge Cases (explicit handling in v0.1)

1. **Sensor reports no data ("Measuring...")** → Display "—" instead of a number. Suspend zone evaluation until valid data resumes. No false warnings.
2. **User configures min ≥ max** → UI prevents this (when adjusting min via crown, it cannot exceed max-1; same for max).
3. **Watch display darkens during workout** → Workout continues in background due to Workout Processing entitlement. Haptics still fire.
4. **App force-quit during session** → Not handled in v0.1. User must restart manually. Workout data up to that point is lost.
5. **Low battery** → No special handling. Standard watchOS behavior applies.
6. **HealthKit permission denied** → Alert shown with guidance to enable access in Settings. Workout does not start.

## Plan Mode (Structured Workouts)

In addition to the simple single-zone mode, the app supports structured workout plans with multiple phases.

### Presets

Two built-in templates:

| Plan | Phases | Description |
|------|--------|-------------|
| Tempo | 3 phases | 5 min warmup → 20 min tempo → 5 min cooldown |
| Intervall | 9 phases | Warmup → 4× (4 min high + 2 min recovery) → Cooldown |

### Plan behavior

- Each phase has its own HR zone (min/max), adjustable via Digital Crown before starting
- Timed phases auto-advance when their duration expires
- Open-ended phases (warmup/cooldown with ∞ duration) require manual "Next" tap
- Zone state, tolerance counters, and warnings reset on phase transitions
- Startup haptic fires on each phase change
- Last phase stays active until the user taps Stop

### Workout View (during workout)

- Large heart rate number, color-coded (blue = below, green = in zone, red = above)
- Zone state label ("IN ZONE" / "BELOW" / "ABOVE")
- Linear gauge with zone-colored gradient (blue → green → red) showing HR position
- Subtle background color matching zone state
- In plan mode: phase label, phase counter (e.g. "2/3"), time remaining or ∞
- "Next" button (only for open-ended phases), "Stop" button

## Explicit non-goals

The following are intentionally **not** included, even if technically feasible:

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

Version numbers refer to internal milestones, not App Store releases.

- **v0.1** — minimum viable feedback app, single zone, fixed timing, manual config on watch
- **v0.2** — plan mode (structured workouts with multi-phase intervals), gauge UI, workout view redesign
