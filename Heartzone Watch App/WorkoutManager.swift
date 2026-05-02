import HealthKit
import Observation
import WatchKit

enum ZoneState {
    case inZone, aboveZone, belowZone
}

struct WorkoutPhase: Identifiable {
    let id = UUID()
    var duration: TimeInterval?
    var minHR: Int
    var maxHR: Int
    var label: String
}

struct WorkoutPlan: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    var phases: [WorkoutPhase]

    static let presets: [WorkoutPlan] = [
        WorkoutPlan(
            name: "Tempo",
            description: "30 min",
            phases: [
                WorkoutPhase(duration: 300, minHR: 110, maxHR: 130, label: "Warmup"),
                WorkoutPhase(duration: 1200, minHR: 145, maxHR: 165, label: "Tempo"),
                WorkoutPhase(duration: 300, minHR: 110, maxHR: 130, label: "Cooldown"),
            ]
        ),
        WorkoutPlan(
            name: "Intervall",
            description: "4×4 min",
            phases: [
                WorkoutPhase(duration: nil, minHR: 110, maxHR: 130, label: "Warmup"),
                WorkoutPhase(duration: 240, minHR: 155, maxHR: 175, label: "Belastung"),
                WorkoutPhase(duration: 120, minHR: 120, maxHR: 140, label: "Erholung"),
                WorkoutPhase(duration: 240, minHR: 155, maxHR: 175, label: "Belastung"),
                WorkoutPhase(duration: 120, minHR: 120, maxHR: 140, label: "Erholung"),
                WorkoutPhase(duration: 240, minHR: 155, maxHR: 175, label: "Belastung"),
                WorkoutPhase(duration: 120, minHR: 120, maxHR: 140, label: "Erholung"),
                WorkoutPhase(duration: 240, minHR: 155, maxHR: 175, label: "Belastung"),
                WorkoutPhase(duration: nil, minHR: 110, maxHR: 130, label: "Cooldown"),
            ]
        ),
    ]
}

@Observable
class WorkoutManager: NSObject {
    let healthStore = HKHealthStore()
    var session: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?

    var heartRate: Double?
    var zoneState: ZoneState = .inZone
    var authorizationDenied = false

    var minHR = 130
    var maxHR = 150

    var phases: [WorkoutPhase] = []
    var currentPhaseIndex = 0
    var phaseElapsedSeconds = 0

    var isPlanMode: Bool { !phases.isEmpty }

    var currentPhase: WorkoutPhase? {
        guard isPlanMode, currentPhaseIndex < phases.count else { return nil }
        return phases[currentPhaseIndex]
    }

    var phaseTimeRemaining: TimeInterval? {
        guard let phase = currentPhase, let duration = phase.duration else { return nil }
        return max(0, duration - TimeInterval(phaseElapsedSeconds))
    }

    private var secondsOutsideZone = 0
    private var secondsSinceLastWarning = 0
    private var evaluationTimer: Timer?

    func requestAuthorization() async -> Bool {
        let typesToShare: Set<HKSampleType> = [.workoutType()]
        let typesToRead: Set<HKObjectType> = [HKQuantityType(.heartRate)]
        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            return true
        } catch {
            authorizationDenied = true
            return false
        }
    }

    func startWorkout(minHR: Int, maxHR: Int) async {
        self.minHR = minHR
        self.maxHR = maxHR
        self.phases = []
        do { try await beginWorkoutSession() } catch {}
    }

    func startPlanWorkout(phases: [WorkoutPhase]) async {
        self.phases = phases
        self.currentPhaseIndex = 0
        self.phaseElapsedSeconds = 0
        guard let first = phases.first else { return }
        self.minHR = first.minHR
        self.maxHR = first.maxHR
        do { try await beginWorkoutSession() } catch {}
    }

    private func beginWorkoutSession() async throws {
        let config = HKWorkoutConfiguration()
        config.activityType = .cycling
        config.locationType = .outdoor

        session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
        builder = session?.associatedWorkoutBuilder()
        builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore,
                                                      workoutConfiguration: config)
        session?.delegate = self
        builder?.delegate = self

        let start = Date()
        session?.startActivity(with: start)
        try await builder?.beginCollection(at: start)

        playStartupPattern()
        startZoneEvaluation()
    }

    func endWorkout() async {
        stopZoneEvaluation()
        session?.end()
        try? await builder?.endCollection(at: Date())
        _ = try? await builder?.finishWorkout()
        heartRate = nil
        phases = []
    }

    func skipToNextPhase() {
        advanceToNextPhase()
    }

    // MARK: - Zone evaluation

    private func startZoneEvaluation() {
        evaluationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let manager = self else { return }
            Task { @MainActor in
                manager.evaluateZone()
            }
        }
    }

    private func stopZoneEvaluation() {
        evaluationTimer?.invalidate()
        evaluationTimer = nil
        zoneState = .inZone
        secondsOutsideZone = 0
        secondsSinceLastWarning = 0
    }

    private func evaluateZone() {
        if isPlanMode {
            phaseElapsedSeconds += 1
            if let phase = currentPhase, let duration = phase.duration,
               TimeInterval(phaseElapsedSeconds) >= duration {
                advanceToNextPhase()
            }
        }

        guard let hr = heartRate else { return }

        let inRange = hr >= Double(minHR) && hr <= Double(maxHR)

        switch zoneState {
        case .inZone:
            if inRange {
                secondsOutsideZone = 0
            } else {
                secondsOutsideZone += 1
                if secondsOutsideZone >= 5 {
                    let newState: ZoneState = hr > Double(maxHR) ? .aboveZone : .belowZone
                    zoneState = newState
                    secondsOutsideZone = 0
                    secondsSinceLastWarning = 0
                    if newState == .aboveZone { playAboveZonePattern() } else { playBelowZonePattern() }
                    print("Zone transition: inZone → \(zoneState)")
                }
            }

        case .belowZone:
            if inRange {
                print("Zone transition: belowZone → inZone")
                zoneState = .inZone
                secondsOutsideZone = 0
                secondsSinceLastWarning = 0
            } else {
                secondsSinceLastWarning += 1
                if secondsSinceLastWarning >= 60 {
                    secondsSinceLastWarning = 0
                    playBelowZonePattern()
                }
            }

        case .aboveZone:
            if inRange {
                print("Zone transition: aboveZone → inZone")
                zoneState = .inZone
                secondsOutsideZone = 0
                secondsSinceLastWarning = 0
            } else {
                secondsSinceLastWarning += 1
                if secondsSinceLastWarning >= 15 {
                    secondsSinceLastWarning = 0
                    playAboveZonePattern()
                }
            }
        }
    }

    private func advanceToNextPhase() {
        guard currentPhaseIndex < phases.count - 1 else { return }
        currentPhaseIndex += 1
        phaseElapsedSeconds = 0

        let phase = phases[currentPhaseIndex]
        minHR = phase.minHR
        maxHR = phase.maxHR

        zoneState = .inZone
        secondsOutsideZone = 0
        secondsSinceLastWarning = 0

        playStartupPattern()
        print("Phase advance: → \(phase.label) (\(currentPhaseIndex + 1)/\(phases.count))")
    }

    // MARK: - Haptic patterns

    func playBelowZonePattern() {
        WKInterfaceDevice.current().play(.notification)
    }

    func playAboveZonePattern() {
        let device = WKInterfaceDevice.current()
        Task {
            device.play(.failure)
            try? await Task.sleep(for: .seconds(1))
            device.play(.failure)
            try? await Task.sleep(for: .seconds(1))
            device.play(.failure)
        }
    }

    func playStartupPattern() {
        let device = WKInterfaceDevice.current()
        Task {
            device.play(.click)
            try? await Task.sleep(for: .milliseconds(600))
            device.play(.click)
            try? await Task.sleep(for: .milliseconds(600))
            device.play(.click)
            try? await Task.sleep(for: .milliseconds(600))
            device.play(.notification)
        }
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState,
                                    date: Date) {
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didFailWithError error: Error) {
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
    }

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                    didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard collectedTypes.contains(HKQuantityType(.heartRate)) else { return }

        let statistics = workoutBuilder.statistics(for: HKQuantityType(.heartRate))
        let unit = HKUnit.count().unitDivided(by: .minute())
        let value = statistics?.mostRecentQuantity()?.doubleValue(for: unit)

        Task { @MainActor in
            self.heartRate = value
        }
    }
}
