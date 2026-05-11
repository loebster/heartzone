import HealthKit
import Observation
import SwiftUI
import WatchKit

enum ZoneState {
    case inZone, aboveZone, belowZone
}

struct Phase: Codable, Identifiable {
    var id = UUID()
    var name: String
    var minHR: Int
    var maxHR: Int
    var duration: TimeInterval?
}

struct Plan: Codable, Identifiable {
    var id = UUID()
    var name: String
    var phases: [Phase]
}

enum PlanNames {
    static let plans: [String] = [
        "Custom A", "Custom B", "Custom C", "Tempo", "Intervall", "Endurance",
        "Recovery Ride", "Threshold", "Long Ride", "Easy Day", "Race Pace",
        "Sunday Roller", "Hill Hunter", "Pace Pusher", "Cruise Mode", "Vento",
        "Solo Break", "Domestique", "Climber", "Schmerzgrenze", "Espresso Ride",
        "Pretzel Legs", "Lactate Shuttle", "Watt's Up",
    ]

    static let phases: [String] = [
        "Warm-up", "Easy", "Tempo", "Threshold", "Sweet Spot", "Interval",
        "Surge", "Recovery", "Active Rest", "Cooldown", "Free", "Push",
    ]
}

@Observable
class PlanStore {
    var plans: [Plan] = []

    init() {
        load()
        seedIfNeeded()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(plans) else { return }
        UserDefaults.standard.set(data, forKey: "savedPlans")
    }

    func availablePlanNames(excluding currentName: String? = nil) -> [String] {
        let usedNames = Set(plans.map(\.name))
        var available = PlanNames.plans.filter { !usedNames.contains($0) }
        if let current = currentName, !available.contains(current) {
            available.insert(current, at: 0)
        }
        if available.isEmpty {
            var code = UnicodeScalar("D").value
            while usedNames.contains("Custom \(UnicodeScalar(code)!)") { code += 1 }
            available.append("Custom \(UnicodeScalar(code)!)")
        }
        return available
    }

    @discardableResult
    func addPlan() -> Plan {
        let name = availablePlanNames().first ?? "Custom"
        let plan = Plan(name: name, phases: [])
        plans.append(plan)
        save()
        return plan
    }

    func deletePlan(at offsets: IndexSet) {
        plans.remove(atOffsets: offsets)
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: "savedPlans"),
              let decoded = try? JSONDecoder().decode([Plan].self, from: data) else { return }
        plans = decoded
    }

    private func seedIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "plansSeeded") else { return }
        plans = [
            Plan(name: "Tempo", phases: [
                Phase(name: "Warm-up", minHR: 110, maxHR: 125, duration: 300),
                Phase(name: "Tempo", minHR: 140, maxHR: 155, duration: 1200),
                Phase(name: "Cooldown", minHR: 110, maxHR: 125, duration: 300),
            ]),
            Plan(name: "Intervall", phases: [
                Phase(name: "Warm-up", minHR: 110, maxHR: 125, duration: 300),
                Phase(name: "Interval", minHR: 160, maxHR: 175, duration: 240),
                Phase(name: "Recovery", minHR: 120, maxHR: 135, duration: 120),
                Phase(name: "Interval", minHR: 160, maxHR: 175, duration: 240),
                Phase(name: "Recovery", minHR: 120, maxHR: 135, duration: 120),
                Phase(name: "Interval", minHR: 160, maxHR: 175, duration: 240),
                Phase(name: "Recovery", minHR: 120, maxHR: 135, duration: 120),
                Phase(name: "Interval", minHR: 160, maxHR: 175, duration: 240),
                Phase(name: "Cooldown", minHR: 110, maxHR: 125, duration: 300),
            ]),
        ]
        UserDefaults.standard.set(true, forKey: "plansSeeded")
        save()
    }
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

    var phases: [Phase] = []
    var currentPhaseIndex = 0
    var phaseElapsedSeconds = 0

    var isPlanMode: Bool { !phases.isEmpty }

    var currentPhase: Phase? {
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

    func startPlanWorkout(phases: [Phase]) async {
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
        print("Phase advance: → \(phase.name) (\(currentPhaseIndex + 1)/\(phases.count))")
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
