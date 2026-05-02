# HeartZone — Architecture Decision Log

A running log of decisions made during the project, with reasoning. Add new entries at the top. Format: date, decision, rationale, alternatives considered.

---

## 2026-05-02: Haptic pattern redesign after hardware reality check

**Decision:** Abandon the "embodied mirror" pattern design. Differentiate zones purely by tap count: 1× `.notification` for below zone, 3× `.notification` for above zone. Both use the same haptic type (`.notification`, the strongest available).

**Rationale:** The original design required varying haptic duration and intensity — a "long, slow pulse" for below zone and "three short, fast pulses" for above. watchOS does not support CoreHaptics; `WKInterfaceDevice.play()` produces only fixed short impulses with no control over duration or intensity. After 4 rounds of real-watch iteration, the distinction by count proved to be the most reliably perceptible approach within the platform's constraints.

**Alternatives considered:**
- Using different `WKHapticType` values for each zone (`.directionUp` vs. `.directionDown`). Tested; the types felt too similar and too faint during cycling to be distinguished.
- Rapid-fire sequences with short gaps (150ms). Tested; calls closer than ~600ms cancel each other or blend into an indistinct mush per Apple's documentation (minimum 100ms enforced delay).

---

## 2026-05-02: Below-zone warning interval changed to 60 seconds

**Decision:** Below-zone warnings repeat every 60 seconds. Above-zone warnings remain at 15 seconds.

**Rationale:** During real-watch testing, the 15-second interval for below-zone was immediately annoying at traffic lights and other brief stops. Being below the zone is typically a lower-urgency situation (standing, waiting, coasting). Being above the zone is more urgent (overexertion risk), so it keeps the shorter 15-second interval.

---

## 2026-05-02: Re-entry haptic pattern removed

**Decision:** No haptic fires when the user returns to the zone from above or below. Silence is the re-entry signal.

**Rationale:** User decision during testing: "Nicht zu viele Alerts. Auch kein Re-entry." The cessation of warning haptics is itself an unambiguous signal. Adding a confirmation tap on re-entry would increase overall haptic noise without meaningful benefit, particularly during zone-boundary oscillation.

**Alternatives considered:**
- Single `.success` tap on re-entry. Tested early; felt too similar to system notifications and added noise.
- The original short-long-short pattern. Never deployed to hardware — superseded before real-world testing due to the broader pattern redesign.

---

## 2026-04-29: Haptic semantics — "embodied mirror" instead of "instructive command"

**Decision:** The haptic pattern mirrors the user's physiological state (sluggish pulse for too-low HR, hectic pulses for too-high HR) rather than instructing the user what to do (e.g., "down-arrow" for too-high meaning "slow down").

**Rationale:** During cycling, the user is physically engaged. A haptic that resonates with the bodily state docks more naturally to their experience than an abstract command requiring cognitive translation. Embodiment beats cognition at the handlebar.

**Alternatives considered:**
- "Instruction" model: 1× `.directionUp` for too-low ("speed up"), 2× `.directionDown` for too-high ("slow down"). Cleaner mapping in theory, but adds a translation step in the user's head.

**Superseded 2026-05-02** — see "Haptic pattern redesign after hardware reality check" above.

---

## 2026-04-29: Re-entry confirmation as short-long-short

**Decision:** When the user returns to the zone after being above or below, fire a single confirmation pattern: short — long — short.

**Rationale:** Distinct from both warning patterns (which are pure "short repeated" or pure "long"). The mixed structure is unambiguously identifiable as a third state. Reassures the user without being intrusive.

**Alternatives considered:**
- Pure silence on re-entry. Argued: cessation of warning is itself the signal. Rejected because explicit confirmation is more reassuring during a focused activity.
- A simple `.success` haptic. Rejected because it might be confused with system notifications.

**Superseded 2026-05-02** — see "Re-entry haptic pattern removed" above.

---

## 2026-04-29: Watch-only architecture, no iPhone companion

**Decision:** v0.1 is a watch-only app. Configuration happens on the watch. No iPhone app.

**Rationale:** The whole point of the app is to enable handlebar-free training. Adding an iPhone dependency contradicts that. Configuration in v0.1 is simple enough (min/max via Crown) that it works on the watch screen.

**Alternatives considered:**
- iPhone companion for richer configuration UI. Rejected for v0.1: roughly 2.5–3× the engineering effort for marginal benefit. Re-evaluate if v0.2 introduces interval plans where editing on the watch becomes painful.

---

## 2026-04-29: No "settle-in" period at workout start

**Decision:** Zone evaluation begins immediately when the workout starts. No grace period during which warnings are suppressed.

**Rationale:** Initially proposed a 3-minute warm-up suppression to avoid early-workout false alarms. Rejected on user feedback: the principle of "silence = inside, vibration = outside" is the app's clarity asset. Adding a hidden override at the start contradicts this. A single haptic every 15 seconds while warming up is acceptable, not overwhelming.

---

## 2026-04-29: 15-second warning interval, 5-second tolerance window

**Decision:** Warnings repeat every 15s while outside the zone. Trigger only after 5 consecutive seconds outside the zone.

**Rationale:** Educated guesses, not yet validated. 15s avoids both pestering and sluggishness. 5s filters sensor noise without delaying meaningful warnings. Both values are documented as "to be tuned with real-world data" and explicitly **not** exposed as user settings in v0.1, to keep the surface small.

**Status:** Provisional. Will be revisited after first real ride.

---

## 2026-04-29: Tooling — Claude Agent inside Xcode

**Decision:** Use Xcode 26.4.1's built-in Claude Agent for implementation, instead of Claude Code in a separate terminal.

**Rationale:** Xcode 26.3+ ships a native integration of the Claude Agent SDK with access to Xcode's build tools, Apple documentation search, and SwiftUI Preview verification. For a SwiftUI/watchOS project this is the optimal toolchain. User has Claude Max subscription, which covers agent usage. One tool open instead of two.

**Alternatives considered:**
- Claude Code in CLI. User has experience with it. Rejected because the in-Xcode integration provides additional capabilities specific to this project type (preview verification, native build loop). Fallback option remains if the Xcode integration disappoints.

---

## 2026-04-29: GitHub repository, public

**Decision:** Project lives in a public GitHub repository.

**Rationale:** Enables Claude (the consultant in chat) to read source files via URL when needed. User has no commercialization plans for v0.1, so privacy of source is not a concern. Standard `.gitignore` for Xcode projects protects against accidentally committing user-specific files.

**Alternatives considered:**
- Private repository. Rejected because Claude in chat cannot read private repos.
- No version control. Rejected — versioning is hygiene for any non-trivial project.
