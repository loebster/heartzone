# HeartZone — Backlog

Ideas considered but not included in v0.1. Triaged into "promising", "uncertain", and "probably not". Re-evaluate after real-world testing of v0.1.

---

## Promising — likely candidates for v0.2 or v0.3

### Quiet re-entry hysteresis

After returning to the zone from outside, suppress new warnings for ~30 seconds even if the user briefly drifts out again. Prevents haptic ping-pong at zone boundaries.

**Why later:** Want to first see in real rides whether ping-pong actually occurs. May not be a real problem. Adding this preemptively risks suppressing legitimate warnings.

---

### Adaptive tolerance buffer ("gray zone")

Instead of a hard zone boundary, configure an inner zone (silence) and an outer warning zone (action). E.g., zone 130–150 with gray zone 125–155, warning only outside gray. Reduces over-eager alarms.

**Why later:** Same reason — needs real-world data to know if it's helpful. Also adds two more sliders to a simple UI.

---

### Tap-to-snooze

Tap the watch screen during a workout → 2 minutes of silence regardless of HR. For hills, traffic lights, breaks. Then normal logic resumes.

**Why later:** Cheap to build, but want to confirm in real rides that it solves a real problem. Risk: if it's used reflexively, the user may be tuning out the system instead of training with it.

---

### End-of-workout summary on the watch

After Stop, show a brief summary: "72% in zone, 18% above, 10% below." Three lines, fades after a few seconds.

**Why later:** Apple Health already records this. Showing it directly on the watch is a UX nicety, not core. Add when other things are stable.

---

### Quick-adjust during workout (Digital Crown shifts zone)

While riding, turning the Crown shifts both min and max by the same amount, keeping zone width constant. Tap to confirm.

**Why later:** Useful for live tuning ("I feel stronger today, push the zone up 5"). But requires careful UX so accidental Crown turns don't shift the zone. Worth doing, but not for v0.1.

---

## Uncertain — needs more thought

### Haptic intensity that scales with deviation

The further outside the zone, the more urgent the haptic (faster repeat or doubled pattern).

**Why uncertain:** Conceptually appealing, but adds complexity. The user already feels their own state. Is more nuance from the watch actually useful? Possibly redundant.

---

### Optional audio cues (when AirPods connected)

Short, non-voice tones — low note for "too low", high note for "too high". Off by default. For users who can't reliably feel haptics through cycling kit.

**Why uncertain:** Solves a real problem (winter gloves, thick jersey), but mixes the simple haptic-only philosophy with another modality. Worth keeping in mind, not urgent.

---

### Eskalations-Pattern (3 levels deep above zone)

If the user is above max for >2 minutes, escalate to a more urgent pattern.

**Why uncertain:** May be paternalistic. The user knows they're pushing hard. Don't want a nagging app. Re-evaluate after real-world data shows whether prolonged over-zone happens often enough to warrant this.

---

## Schubladen-Träumereien — probably not, but logged for completeness

### Tour mode with GPX route + elevation profile

Pre-loaded GPX file. App knows: "in 2 minutes a climb starts, zone shifts +10 bpm temporarily." Avoids false alarms during climbs.

**Why probably not:** Lot of engineering (GPX parsing, GPS tracking, route matching). Cool idea, but a different product. Not a v0.x evolution.

---

### Coach mode — minimal voice in AirPods

Single-word voice cues — "pace", "push" — instead of haptics, for users who prefer audio. Strictly minimal, no full sentences.

**Why probably not:** Niche use case. Voice modality fundamentally different from haptic philosophy. Worth a separate experiment, not an integrated feature.

---

### Group ride mode

Multiple watches in same app group. Each rider has their profile. If one rider crosses a danger threshold (very high or very low HR), all riders get an alert.

**Why probably not:** Different product. Cloud sync, multi-device coordination, permissions. Not in scope.

---

### "Honest mirror" end summary

Instead of "Great, you spent 72% in zone!" — say "You wasted 18% of training time outside zone." Provocative but honest framing, differentiating from soft fitness apps.

**Why probably not:** Designer statement, not a feature. Personal taste. May not age well. If we ever ship publicly, this is a brand decision.

---

### Interval training plans

Phase A: 4 min in zone X. Phase B: 1 min in zone Y. Repeat. Pre-configurable.

**Why later, not now:** This is the natural v0.2 direction if v0.1 proves the concept. Probably the first major feature addition. Triggers the iPhone-companion question because plan editing on the watch is painful.

---

### Multiple saved profiles

City cruise (130–145), tempo (155–170), endurance (140–155). Quick-switch.

**Why later, not now:** Closely related to interval plans. Same reasoning — wait for v0.1 to prove the basic mechanic.

---

### External Bluetooth chest strap support

For higher accuracy and lower latency than the watch's optical sensor.

**Why later:** Optical sensor latency is a real limitation but acceptable for steady-state training. Becomes important for short, sharp intervals. Adds Core Bluetooth complexity. Defer until interval training is on the table.
