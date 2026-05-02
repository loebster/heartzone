import HealthKit
import Observation
import WatchKit

enum ZoneState {
    case inZone, aboveZone, belowZone
}

@Observable
class WorkoutManager: NSObject {
    let healthStore = HKHealthStore()
    var session: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?

    var heartRate: Double?
    var zoneState: ZoneState = .inZone
    var authorizationDenied = false

    private var minHR = 130
    private var maxHR = 150
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

        let config = HKWorkoutConfiguration()
        config.activityType = .cycling
        config.locationType = .outdoor

        do {
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
        } catch {
            // Error handling deferred to Step 7
        }
    }

    func endWorkout() async {
        stopZoneEvaluation()
        session?.end()
        try? await builder?.endCollection(at: Date())
        _ = try? await builder?.finishWorkout()
        heartRate = nil
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

    // MARK: - Haptic patterns

    func playBelowZonePattern() {
        WKInterfaceDevice.current().play(.notification)
    }

    func playAboveZonePattern() {
        let device = WKInterfaceDevice.current()
        Task {
            device.play(.notification)
            try? await Task.sleep(for: .seconds(1))
            device.play(.notification)
            try? await Task.sleep(for: .seconds(1))
            device.play(.notification)
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
