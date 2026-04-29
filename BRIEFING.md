# HeartZone — Briefing for the Coding Agent

You are implementing **HeartZone v0.1**, a watchOS app. This document is your starting point.

## Required reading before you write any code

Read these files in this order:

1. **`SPEC.md`** — the functional and technical specification. Treat this as authoritative.
2. **`DECISIONS.md`** — the reasoning behind key design choices. Reference this when in doubt about *why* something is the way it is.
3. **`BACKLOG.md`** — explicitly out of scope for v0.1. Do not implement anything from here.

If anything in this briefing contradicts `SPEC.md`, the spec wins. Flag the contradiction to the user.

## What you are building

A watchOS app that gives directional haptic feedback during cycling workouts based on whether the wearer's heart rate is inside, above, or below a configured target zone. Silence inside the zone. Distinct haptic patterns when above vs. below.

This is an **independent watch app** — no iPhone companion. v0.1 is intentionally minimal.

## Implementation order

Build in this sequence. Do not skip ahead. After each step, stop and let the user verify before continuing.

### Step 1 — Project capabilities & permissions

Set up everything required for HealthKit and background workout processing **before** writing logic. Specifically:

- Add the **HealthKit** capability to the watch app target.
- Enable **Background Modes** with **Workout Processing** checked.
- Add the two `Info.plist` usage description strings (text per `SPEC.md`):
  - `NSHealthShareUsageDescription`
  - `NSHealthUpdateUsageDescription`

Verify: build succeeds, capabilities visible in target settings.

### Step 2 — Main view with min/max configuration

A single SwiftUI view showing:

- Current min HR (default 130)
- Current max HR (default 150)
- A Start button

Both values are adjustable via Digital Crown when focused. Persist values via `@AppStorage`.

UI constraint: min cannot be set ≥ max, and vice versa. Enforce in the binding logic.

Do not yet wire up the workout session. Tapping Start should just navigate to a placeholder workout view.

Verify in the simulator: values change with crown, persist across app restarts, min/max constraint holds.

### Step 3 — Workout session with live heart rate

Implement the workout view:

- Start an `HKWorkoutSession` with `.cycling` activity type, `.outdoor` location.
- Use `HKLiveWorkoutBuilder` to subscribe to live `heartRate` data.
- Display the current HR as a large central number, with min/max shown smaller for reference.
- Stop button ends the session and saves the workout to Health.

Edge case from spec: when no HR data is available, show "—" instead of a number, and suspend zone evaluation in later steps.

Verify on a **real Apple Watch** (sideloaded), not in the simulator — the simulator doesn't generate heart rate data. Personal Team signing is fine for v0.1.

### Step 4 — Zone evaluation state machine

Implement the state machine described in `SPEC.md`:

- States: `inZone`, `aboveZone`, `belowZone`
- Transition into above/below requires 5 consecutive seconds outside the zone (tolerance window)
- Transition back to `inZone` is immediate (no debounce on re-entry)

Don't fire haptics yet. Just log state transitions to the console for verification.

Verify on a real watch by raising/lowering your heart rate (climb stairs).

### Step 5 — Haptic patterns

Implement the three patterns from `SPEC.md`:

- **Below zone:** "long, slow pulse" — implementation hint: 2× `.directionDown` in rapid succession
- **Above zone:** "three short, fast pulses" — implementation hint: 3× `.notification` or `.click` with ~150ms gap
- **Re-entry:** "short — long — short" — implementation hint: `.click` + `.directionDown` + `.click`

Wire to the state machine: warning patterns repeat every 15 seconds while outside; re-entry pattern fires once when entering `inZone` from above or below.

Use `WKInterfaceDevice.current().play(...)` for haptics. Sequence patterns with `DispatchQueue.main.asyncAfter` or a `Task` with `try await Task.sleep`.

### Step 6 — Pattern test screen

Add a "Test Patterns" button on the main configuration view (not visible during a workout). Tapping it navigates to a screen with three buttons that each fire one of the three patterns. This lets the user feel the patterns outside of a workout for tuning.

### Step 7 — Polish

- App icon (placeholder fine for v0.1)
- App name shown correctly on the watch
- Gracefully handle the user denying HealthKit permission

## Constraints and house rules

- **Swift 5.9+ / SwiftUI / watchOS 10+** target.
- Single-file architecture is fine for v0.1. Don't pre-engineer for scale. Two or three Swift files maximum is the right magnitude.
- **No third-party dependencies.** Pure Apple frameworks only.
- **No analytics, no telemetry, no network calls.** This app is fully local.
- **No login, no accounts, no cloud.**
- Keep the UI minimal. No animations beyond what SwiftUI gives for free. No custom fonts. System defaults throughout.
- Code comments in English.
- Commit after each completed step with a clear message. Push to the GitHub remote.

## Things to verify with the user before deciding

If you encounter any of the following, **stop and ask** rather than choosing on your own:

- A spec ambiguity not resolvable from `SPEC.md` or `DECISIONS.md`
- A trade-off between simplicity and a "nice-to-have" not listed in the spec
- A platform constraint that prevents the spec from being implemented as written (e.g., haptic limitations on this watch model)
- Anything that would change persisted user data formats (none yet, but for future-proofing)

The user prefers concise replies. When asking, list the options briefly with your recommendation.

## Things you do NOT need to ask about

These are pre-decided and in `DECISIONS.md`:

- Watch-only architecture (no iPhone companion in v0.1)
- Haptic semantics (embodied mirror, not instructive command)
- Re-entry pattern (short-long-short)
- 15-second warning interval, 5-second tolerance
- No settle-in period at workout start
- English UI

## Tooling notes

- **Real-watch testing is required** for haptic patterns. Simulator cannot reproduce haptic feel.
- Use Xcode's Preview for SwiftUI iteration where possible, but anything involving HealthKit requires the real device.
- The user is on Personal Team signing (no paid Apple Developer Program). This means apps installed on-device expire after 7 days. That's acceptable for v0.1.

## Definition of done for v0.1

- App installed on user's Apple Watch
- User starts a workout, configures zone via crown, rides for 30+ minutes
- Haptic patterns fire correctly above/below/re-entry
- No crashes, no UI glitches, no false alarms during steady-state riding
- Workout appears in Apple Health afterward
- User reports the feel as "right enough to keep using" — full tuning is allowed for v0.2

If any of these are unmet after a real-world test, document the issue and propose the smallest possible fix rather than a redesign.
