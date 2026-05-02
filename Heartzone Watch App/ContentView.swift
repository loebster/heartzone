import SwiftUI

struct ContentView: View {
    @AppStorage("minHeartRate") private var minHR: Double = 130
    @AppStorage("maxHeartRate") private var maxHR: Double = 150
    @FocusState private var focusedField: Field?
    @State private var workoutManager = WorkoutManager()
    @State private var showWorkout = false

    private enum Field {
        case min, max
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                heartRateRow("Min", value: $minHR, field: .min,
                             range: 50...(maxHR - 1))
                heartRateRow("Max", value: $maxHR, field: .max,
                             range: (minHR + 1)...220)

                Button("Start") {
                    Task {
                        guard await workoutManager.requestAuthorization() else { return }
                        await workoutManager.startWorkout(minHR: Int(minHR),
                                                          maxHR: Int(maxHR))
                        showWorkout = true
                    }
                }
                .tint(.green)
                .alert("Health Access Required",
                       isPresented: $workoutManager.authorizationDenied) {
                    Button("OK") {}
                } message: {
                    Text("Open Settings → Health → HeartZone to grant access.")
                }

                NavigationLink("Plan") {
                    PlanListView(manager: workoutManager)
                }

                // NavigationLink("Haptics") {
                //     HapticTestView()
                // }
                // .font(.caption)
            }
            .navigationTitle("HeartZone")
            .navigationDestination(isPresented: $showWorkout) {
                WorkoutView(manager: workoutManager)
            }
        }
    }

    private func heartRateRow(_ label: String, value: Binding<Double>,
                              field: Field, range: ClosedRange<Double>) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(Int(value.wrappedValue))")
                .font(.title2.monospacedDigit())
                .foregroundStyle(focusedField == field ? .green : .primary)
            Text("bpm")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .focusable()
        .focused($focusedField, equals: field)
        .digitalCrownRotation(value, from: range.lowerBound, through: range.upperBound,
                              by: 1, sensitivity: .medium,
                              isContinuous: false, isHapticFeedbackEnabled: true)
    }
}

// MARK: - Workout View

struct WorkoutView: View {
    var manager: WorkoutManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 6) {
            Text(heartRateText)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(heartRateColor)

            Text(zoneLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(heartRateColor)

            Gauge(value: gaugeValue, in: gaugeMin...gaugeMax) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            } minimumValueLabel: {
                Text("\(manager.minHR)")
                    .font(.caption2)
            } maximumValueLabel: {
                Text("\(manager.maxHR)")
                    .font(.caption2)
            }
            .gaugeStyle(.linearCapacity)
            .tint(zoneGradient)

            if manager.isPlanMode, let phase = manager.currentPhase {
                HStack(spacing: 4) {
                    Text(phase.label)
                    Text("·")
                    Text("\(manager.currentPhaseIndex + 1)/\(manager.phases.count)")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                if let remaining = manager.phaseTimeRemaining {
                    Text(formatTime(remaining))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text("∞")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                if manager.isPlanMode,
                   manager.currentPhase?.duration == nil,
                   manager.currentPhaseIndex < manager.phases.count - 1 {
                    Button("Next") {
                        manager.skipToNextPhase()
                    }
                    .tint(.blue)
                }

                Button("Stop") {
                    Task {
                        await manager.endWorkout()
                        dismiss()
                    }
                }
                .tint(.red)
            }
        }
        .containerBackground(for: .navigation) {
            heartRateColor.opacity(0.15)
        }
        .navigationBarBackButtonHidden()
    }

    private var heartRateText: String {
        guard let hr = manager.heartRate else { return "—" }
        return "\(Int(hr))"
    }

    private var zoneLabel: String {
        switch manager.zoneState {
        case .inZone: return "IN ZONE"
        case .belowZone: return "BELOW"
        case .aboveZone: return "ABOVE"
        }
    }

    private var heartRateColor: Color {
        guard let hr = manager.heartRate else { return .secondary }
        if hr < Double(manager.minHR) { return .blue }
        if hr > Double(manager.maxHR) { return .red }
        return .green
    }

    private var gaugeValue: Double {
        guard let hr = manager.heartRate else {
            return (Double(manager.minHR) + Double(manager.maxHR)) / 2
        }
        return min(gaugeMax, max(gaugeMin, hr))
    }

    private var gaugeMin: Double { Double(max(50, manager.minHR - 20)) }
    private var gaugeMax: Double { Double(min(220, manager.maxHR + 20)) }

    private var zoneGradient: Gradient {
        let total = gaugeMax - gaugeMin
        let zoneStart = (Double(manager.minHR) - gaugeMin) / total
        let zoneEnd = (Double(manager.maxHR) - gaugeMin) / total
        return Gradient(stops: [
            .init(color: .blue, location: 0),
            .init(color: .blue, location: max(0, zoneStart - 0.01)),
            .init(color: .green, location: zoneStart),
            .init(color: .green, location: zoneEnd),
            .init(color: .red, location: min(1, zoneEnd + 0.01)),
            .init(color: .red, location: 1),
        ])
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Plan Views

struct PlanListView: View {
    var manager: WorkoutManager

    var body: some View {
        List(WorkoutPlan.presets) { plan in
            NavigationLink {
                PlanDetailView(manager: manager, phases: plan.phases, planName: plan.name)
            } label: {
                VStack(alignment: .leading) {
                    Text(plan.name)
                        .font(.headline)
                    Text(plan.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Plans")
    }
}

struct PlanDetailView: View {
    @Bindable var manager: WorkoutManager
    @State private var phases: [WorkoutPhase]
    @State private var showWorkout = false
    let planName: String

    init(manager: WorkoutManager, phases: [WorkoutPhase], planName: String) {
        self.manager = manager
        self._phases = State(initialValue: phases)
        self.planName = planName
    }

    var body: some View {
        List {
            ForEach(phases.indices, id: \.self) { index in
                NavigationLink {
                    PhaseEditView(phase: $phases[index])
                } label: {
                    phaseRow(phases[index])
                }
            }

            Section {
                Button("Start Plan") {
                    Task {
                        guard await manager.requestAuthorization() else { return }
                        await manager.startPlanWorkout(phases: phases)
                        showWorkout = true
                    }
                }
                .tint(.green)
            }
        }
        .navigationTitle(planName)
        .alert("Health Access Required",
               isPresented: $manager.authorizationDenied) {
            Button("OK") {}
        } message: {
            Text("Open Settings → Health → HeartZone to grant access.")
        }
        .navigationDestination(isPresented: $showWorkout) {
            WorkoutView(manager: manager)
        }
    }

    private func phaseRow(_ phase: WorkoutPhase) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(phase.label)
                    .font(.caption)
                Text("\(phase.minHR)–\(phase.maxHR) bpm")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let d = phase.duration {
                Text(formatDuration(d))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Text("∞")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if secs == 0 { return "\(mins) min" }
        return String(format: "%d:%02d", mins, secs)
    }
}

struct PhaseEditView: View {
    @Binding var phase: WorkoutPhase
    @FocusState private var focusedField: Field?

    private enum Field {
        case min, max
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Min")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(phase.minHR)")
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(focusedField == .min ? .green : .primary)
                Text("bpm")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .focusable()
            .focused($focusedField, equals: .min)
            .digitalCrownRotation(
                Binding(
                    get: { Double(phase.minHR) },
                    set: { phase.minHR = Int($0) }
                ),
                from: 50, through: Double(phase.maxHR - 1),
                by: 1, sensitivity: .medium,
                isContinuous: false, isHapticFeedbackEnabled: true
            )

            HStack {
                Text("Max")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(phase.maxHR)")
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(focusedField == .max ? .green : .primary)
                Text("bpm")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .focusable()
            .focused($focusedField, equals: .max)
            .digitalCrownRotation(
                Binding(
                    get: { Double(phase.maxHR) },
                    set: { phase.maxHR = Int($0) }
                ),
                from: Double(phase.minHR + 1), through: 220,
                by: 1, sensitivity: .medium,
                isContinuous: false, isHapticFeedbackEnabled: true
            )
        }
        .navigationTitle(phase.label)
    }
}

struct HapticTestView: View {
    private let device = WKInterfaceDevice.current()

    var body: some View {
        List {
            Button("notification") { device.play(.notification) }
            Button("directionUp") { device.play(.directionUp) }
            Button("directionDown") { device.play(.directionDown) }
            Button("success") { device.play(.success) }
            Button("failure") { device.play(.failure) }
            Button("retry") { device.play(.retry) }
            Button("start") { device.play(.start) }
            Button("stop") { device.play(.stop) }
            Button("click") { device.play(.click) }
        }
        .navigationTitle("Haptics")
    }
}

#Preview("In Zone") {
    NavigationStack {
        WorkoutView(manager: {
            let m = WorkoutManager()
            m.heartRate = 142
            m.zoneState = .inZone
            m.minHR = 130
            m.maxHR = 150
            return m
        }())
    }
}

#Preview("Above Zone") {
    NavigationStack {
        WorkoutView(manager: {
            let m = WorkoutManager()
            m.heartRate = 168
            m.zoneState = .aboveZone
            m.minHR = 130
            m.maxHR = 150
            return m
        }())
    }
}

#Preview("Below Zone") {
    NavigationStack {
        WorkoutView(manager: {
            let m = WorkoutManager()
            m.heartRate = 115
            m.zoneState = .belowZone
            m.minHR = 130
            m.maxHR = 150
            return m
        }())
    }
}

#Preview("Plan Mode") {
    NavigationStack {
        WorkoutView(manager: {
            let m = WorkoutManager()
            m.heartRate = 158
            m.zoneState = .inZone
            m.minHR = 145
            m.maxHR = 165
            m.phases = [
                WorkoutPhase(duration: 300, minHR: 110, maxHR: 130, label: "Warmup"),
                WorkoutPhase(duration: 1200, minHR: 145, maxHR: 165, label: "Tempo"),
                WorkoutPhase(duration: 300, minHR: 110, maxHR: 130, label: "Cooldown"),
            ]
            m.currentPhaseIndex = 1
            m.phaseElapsedSeconds = 420
            return m
        }())
    }
}

#Preview("Start Screen") {
    ContentView()
}
