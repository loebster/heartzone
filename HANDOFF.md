# HeartZone v0.1 — Handoff Notes

Session date: 2026-05-02. Written for the next planning/implementation session.

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

## Files overview

| File | Purpose |
|------|---------|
| `WorkoutManager.swift` | HealthKit session, zone state machine, haptic patterns (~195 lines) |
| `ContentView.swift` | All views: config, workout, pattern test (~147 lines) |
| `HeartzoneApp.swift` | App entry point (unchanged) |
| `Heartzone-Watch-App-Info.plist` | HealthKit usage descriptions, background modes |
| `SPEC.md` | Original spec — **partially outdated** regarding haptic patterns |
| `DECISIONS.md` | Architecture decisions — still accurate for non-haptic decisions |
| `BACKLOG.md` | Future features — unchanged, still valid |

## Recommended next steps

1. **Real ride test** — 30+ minute cycling session. Primary question: are the haptic patterns noticeable and distinct enough while riding?
2. **Update SPEC.md** — Align the haptic pattern section with what was actually built
3. **Update DECISIONS.md** — Add entries for: pattern redesign rationale, 60s below-zone interval, re-entry removal
4. **Consider from BACKLOG.md for v0.2:**
   - Tap-to-snooze (cheap to build, solves the traffic light problem better than 60s interval)
   - Quick-adjust during workout (Crown shifts zone up/down)
   - End-of-workout summary

## Build and deploy

```
Xcode → Heartzone.xcodeproj → select Apple Watch target → Run
```

Personal Team signing. Apps expire after 7 days on device. No paid developer account needed for testing.
