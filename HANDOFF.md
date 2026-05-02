# HeartZone — Handoff Notes

Last updated: 2026-05-02. Written for the next planning/implementation session.

---

## What was built

All 7 steps from `BRIEFING.md` are implemented and deployed to a real Apple Watch. The app runs, starts workouts, reads live heart rate, evaluates zones, and fires haptic patterns.

## Deviations from SPEC.md

These were decided during real-watch testing and iteration:

### Haptic patterns completely redesigned

The original SPEC described an "embodied mirror" approach (slow pulse for too-low, hectic pulses for too-high, short-long-short for re-entry). This was abandoned because **watchOS haptics are fundamentally limited**: `WKInterfaceDevice.play()` produces fixed short impulses only. CoreHaptics is not available on watchOS. No control over duration or intensity.

After 4 rounds of real-watch iteration, the final patterns are:

| State | Pattern | Repeat interval |
|-------|---------|-----------------|
| Below zone | 1× `.notification` | 60 seconds |
| Above zone | 3× `.notification` (1s gaps) | 15 seconds |
| Startup | 3× `.click` + 1× `.notification` ("tick tick tick go") | Once |
| Re-entry | None | — |

### Re-entry haptic removed

SPEC called for a short-long-short confirmation on returning to the zone. Removed by user decision — "Nein, wir brauchen nicht zu viele Alerts. Auch kein Re-entry." Silence on re-entry is the signal.

### Below-zone repeat interval: 60s instead of 15s

Original SPEC had 15s for all warnings. Below-zone changed to 60s because a single tap every 15 seconds was annoying at traffic lights. Above-zone keeps 15s — being over the limit is more urgent.

### Same haptic type for both zones

Both use `.notification` (the strongest available type). Differentiation is purely by count: 1 tap = below, 3 taps = above.

## Things that work well

- Digital Crown configuration is intuitive and fast
- Zone state machine with 5s tolerance filters noise reliably
- Color-coded HR display (blue/green/red) + text label (BELOW/IN ZONE/ABOVE) gives clear visual feedback
- Workout saves correctly to Apple Health

## Known limitations and issues

### Silent Mode required
`.notification` haptic type plays a system sound unless Silent Mode is enabled on the watch. This should either be documented prominently or solved by switching to a silent haptic type (but `.notification` is the strongest).

**Future option:** Add a sound/no-sound toggle in the app. User noted: "Das kann man später als Einstellung vielleicht einstellen."

### Haptic subtlety
Even `.notification` (the strongest type) produces a very short impulse. During intense cycling with thick gloves, it may be hard to feel. This is a platform limitation with no software fix. The 3-tap pattern for above-zone helps because repetition is more noticeable than a single tap.

### No re-entry confirmation
The user may not notice when they return to the zone, since silence is the only signal. Monitor in real rides whether this causes confusion. If it does, consider adding back a single tap on re-entry.

## What was added in v0.2 session (2026-05-02)

### Plan Mode
- Two preset workout templates: Tempo (30 min, 3 phases) and Intervall (4×4 min, 9 phases)
- Each phase has its own HR zone, adjustable via Digital Crown before starting
- Timed phases auto-advance; open-ended phases have a "Next" button
- Zone state and tolerance counters reset on phase transitions

### Workout View redesign
- Linear gauge with zone-colored gradient (blue → green → red)
- Subtle zone-colored background via `.containerBackground`
- Plan mode shows phase label, counter, and time remaining
- "Workout" navigation title removed for more space
- Above-zone haptic changed from `.notification` to `.failure` for better differentiation

### SwiftUI Previews
- 5 named previews for local testing without deploying to watch: In Zone, Above Zone, Below Zone, Plan Mode, Start Screen

## Files overview

| File | Purpose |
|------|---------|
| `WorkoutManager.swift` | HealthKit session, zone state machine, haptic patterns, plan/phase logic, presets (~300 lines) |
| `ContentView.swift` | All views: start screen, workout, plan list, plan detail, phase editor, haptic test (commented out), previews (~435 lines) |
| `HeartzoneApp.swift` | App entry point (unchanged) |
| `SPEC.md` | Functional specification — aligned with current implementation |
| `DECISIONS.md` | Architecture decision log — includes original and superseded entries |
| `BACKLOG.md` | Future features |

## Recommended next steps

1. **Real ride test** — test both simple mode and plan mode on a 30+ minute ride
2. **Consider from BACKLOG.md:**
   - Tap-to-snooze (cheap to build, solves the traffic light problem better than 60s interval)
   - Quick-adjust during workout (Crown shifts zone up/down)
   - End-of-workout summary

## Build and deploy

```
Xcode → Heartzone.xcodeproj → select Apple Watch target → Run
```

Personal Team signing. Apps expire after 7 days on device. No paid developer account needed for testing.
