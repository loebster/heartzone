import SwiftUI

struct ContentView: View {
    @AppStorage("minHeartRate") private var minHR: Double = 130
    @AppStorage("maxHeartRate") private var maxHR: Double = 150
    @State private var workoutManager = WorkoutManager()
    @State private var planStore = PlanStore()
    @State private var showWorkout = false

    private var minHRBinding: Binding<Int> {
        Binding(get: { Int(minHR) }, set: { minHR = Double($0) })
    }

    private var maxHRBinding: Binding<Int> {
        Binding(get: { Int(maxHR) }, set: { maxHR = Double($0) })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    VStack(spacing: 0) {
                        Text("MIN")
                            .font(.system(size: 10))
                            .tracking(1)
                            .foregroundStyle(Color(white: 0.53))
                        Picker("MIN", selection: minHRBinding) {
                            ForEach(50...max(50, Int(maxHR) - 1), id: \.self) { v in
                                Text("\(v)").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 110)
                        .labelsHidden()
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 0) {
                        Text("MAX")
                            .font(.system(size: 10))
                            .tracking(1)
                            .foregroundStyle(Color(white: 0.53))
                        Picker("MAX", selection: maxHRBinding) {
                            ForEach(min(221, Int(minHR) + 1)...220, id: \.self) { v in
                                Text("\(v)").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 110)
                        .labelsHidden()
                    }
                    .frame(maxWidth: .infinity)
                }

                HStack(spacing: 8) {
                    NavigationLink {
                        PlanListView(planStore: planStore, manager: workoutManager)
                    } label: {
                        Text("Plan")
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)

                    Button("Start") {
                        Task {
                            guard await workoutManager.requestAuthorization() else { return }
                            await workoutManager.startWorkout(minHR: Int(minHR),
                                                              maxHR: Int(maxHR))
                            showWorkout = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .alert("Health Access Required",
                       isPresented: $workoutManager.authorizationDenied) {
                    Button("OK") {}
                } message: {
                    Text("Open Settings → Health → HeartZone to grant access.")
                }
            }
            .padding(.top, 16)
            .navigationDestination(isPresented: $showWorkout) {
                WorkoutView(manager: workoutManager)
            }
        }
    }
}

// MARK: - Workout View

struct WorkoutView: View {
    var manager: WorkoutManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if manager.isPlanMode {
                planLayout
            } else {
                freeLayout
            }
        }
        .navigationBarBackButtonHidden()
    }

    // MARK: Free Mode

    private var freeLayout: some View {
        VStack(spacing: 0) {
            ZStack {
                zoneColor
                VStack(spacing: 2) {
                    Text(heartRateText)
                        .font(.system(size: 72, weight: .ultraLight))
                        .foregroundStyle(.white)
                    Text("BPM")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            HStack {
                Spacer()
                stopButton
                Spacer()
            }
            .frame(height: 50)
            .background(Color.black)
        }
        .ignoresSafeArea()
    }

    // MARK: Plan Mode

    private var planLayout: some View {
        VStack(spacing: 0) {
            ZStack {
                zoneColor
                VStack(spacing: 2) {
                    Spacer()

                    if manager.currentPhase != nil {
                        Text(phaseLabel)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.92))
                    }

                    HStack(spacing: 4) {
                        ForEach(0..<manager.phases.count, id: \.self) { i in
                            Circle()
                                .fill(i == manager.currentPhaseIndex ? .white : .white.opacity(0.35))
                                .frame(width: i == manager.currentPhaseIndex ? 7 : 5,
                                       height: i == manager.currentPhaseIndex ? 7 : 5)
                        }
                    }
                    .padding(.top, 2)

                    Text(heartRateText)
                        .font(.system(size: 74, weight: .ultraLight))
                        .tracking(-3)
                        .foregroundStyle(.white)

                    if let phase = manager.currentPhase {
                        Text("\(phase.minHR)–\(phase.maxHR)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    if isLastPhase {
                        Text("Final phase")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Spacer()
                }
            }

            if let next = nextPhase {
                HStack(spacing: 4) {
                    Text("NEXT")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(white: 0.4))
                    Text("\(next.name) · \(next.minHR)–\(next.maxHR)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(white: 0.67))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .frame(height: 22)
                .background(Color(white: 0.08))
            }

            HStack {
                if isOpenEndedPhase {
                    Button {
                        manager.skipToNextPhase()
                    } label: {
                        Text("Next")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 120, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.green, lineWidth: 1.5)
                            .fill(Color(white: 0.1))
                    )
                } else if let remaining = manager.phaseTimeRemaining {
                    Text(formatTime(remaining))
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(.white)
                        .frame(width: 110, height: 40)
                }

                Spacer()
                planStopButton
            }
            .padding(.horizontal, 12)
            .frame(height: 56)
            .background(Color.black)
        }
        .ignoresSafeArea()
    }

    private var phaseLabel: String {
        guard let phase = manager.currentPhase else { return "" }
        if manager.phases.count <= 1 { return phase.name }
        return "\(phase.name) · \(manager.currentPhaseIndex + 1)/\(manager.phases.count)"
    }

    // MARK: Components

    private var stopButton: some View {
        Button {
            Task {
                await manager.endWorkout()
                dismiss()
            }
        } label: {
            Image(systemName: "stop.fill")
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(.red))
        }
        .buttonStyle(.plain)
    }

    private var planStopButton: some View {
        Button {
            Task {
                await manager.endWorkout()
                dismiss()
            }
        } label: {
            Image(systemName: "stop.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.67))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color(red: 0.165, green: 0.165, blue: 0.165))
                        .stroke(Color(white: 0.4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: State

    private var heartRateText: String {
        guard let hr = manager.heartRate else { return "—" }
        return "\(Int(hr))"
    }

    private var zoneColor: Color {
        guard manager.heartRate != nil else { return Color(white: 0.2) }
        switch manager.zoneState {
        case .inZone: return .green
        case .aboveZone: return .red
        case .belowZone: return .blue
        }
    }

    private var isLastPhase: Bool {
        manager.currentPhaseIndex >= manager.phases.count - 1
    }

    private var isOpenEndedPhase: Bool {
        guard let phase = manager.currentPhase else { return false }
        return phase.duration == nil && !isLastPhase
    }

    private var nextPhase: Phase? {
        let nextIndex = manager.currentPhaseIndex + 1
        guard nextIndex < manager.phases.count else { return nil }
        return manager.phases[nextIndex]
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Plan Views

struct PlanListView: View {
    @Bindable var planStore: PlanStore
    var manager: WorkoutManager
    @State private var navigateToPlan: UUID?

    var body: some View {
        Group {
            if planStore.plans.isEmpty {
                Button {
                    let plan = planStore.addPlan()
                    navigateToPlan = plan.id
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
            } else {
                List {
                    ForEach(planStore.plans) { plan in
                        NavigationLink {
                            PlanDetailView(planStore: planStore, planID: plan.id, manager: manager)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(plan.name)
                                    .font(.headline)
                                Text(planSummary(plan))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { planStore.deletePlan(at: $0) }

                    Button {
                        let plan = planStore.addPlan()
                        navigateToPlan = plan.id
                    } label: {
                        Label("New Plan", systemImage: "plus")
                    }
                }
            }
        }
        .navigationTitle("Plans")
        .navigationDestination(item: $navigateToPlan) { planID in
            PlanDetailView(planStore: planStore, planID: planID, manager: manager)
        }
    }

    private func planSummary(_ plan: Plan) -> String {
        if plan.phases.isEmpty { return "empty" }
        let parts = plan.phases.map { p -> String in
            guard let d = p.duration else { return "∞" }
            return "\(Int(d) / 60)"
        }
        return parts.joined(separator: "+") + " min"
    }
}

struct PlanDetailView: View {
    @Bindable var planStore: PlanStore
    let planID: UUID
    @Bindable var manager: WorkoutManager
    @State private var showWorkout = false
    @State private var navigateToPhase: UUID?
    @Environment(\.dismiss) private var dismiss

    private var planIndex: Int? {
        planStore.plans.firstIndex { $0.id == planID }
    }

    var body: some View {
        if let pi = planIndex {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    NavigationLink {
                        Picker("Name", selection: $planStore.plans[pi].name) {
                            ForEach(planStore.availablePlanNames(excluding: planStore.plans[pi].name), id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .navigationTitle("Name")
                    } label: {
                        Text(planStore.plans[pi].name)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    if !planStore.plans[pi].phases.isEmpty {
                        Button {
                            Task {
                                guard await manager.requestAuthorization() else { return }
                                await manager.startPlanWorkout(phases: planStore.plans[pi].phases)
                                showWorkout = true
                            }
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(.green))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 4)

                List {
                    Section {
                        ForEach(planStore.plans[pi].phases) { phase in
                            NavigationLink {
                                PhaseEditView(planStore: planStore, planID: planID, phaseID: phase.id)
                            } label: {
                                phaseRow(phase)
                            }
                        }
                        .onDelete { offsets in
                            planStore.plans[pi].phases.remove(atOffsets: offsets)
                            planStore.save()
                        }

                        Button {
                            let phase = Phase(name: "Free", minHR: 130, maxHR: 150, duration: 300)
                            planStore.plans[pi].phases.append(phase)
                            planStore.save()
                            navigateToPhase = phase.id
                        } label: {
                            Label("Add Phase", systemImage: "plus")
                        }
                    }

                    Section {
                        Button {
                            planStore.plans.removeAll { $0.id == planID }
                            planStore.save()
                            dismiss()
                        } label: {
                            Text("Delete Plan")
                                .font(.system(size: 14))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .onDisappear { planStore.save() }
            .alert("Health Access Required",
                   isPresented: $manager.authorizationDenied) {
                Button("OK") {}
            } message: {
                Text("Open Settings → Health → HeartZone to grant access.")
            }
            .navigationDestination(isPresented: $showWorkout) {
                WorkoutView(manager: manager)
            }
            .navigationDestination(item: $navigateToPhase) { phaseID in
                PhaseEditView(planStore: planStore, planID: planID, phaseID: phaseID)
            }
        }
    }

    private func phaseRow(_ phase: Phase) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(phase.name)
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
    @Bindable var planStore: PlanStore
    let planID: UUID
    let phaseID: UUID
    @Environment(\.dismiss) private var dismiss

    private var planIndex: Int? {
        planStore.plans.firstIndex { $0.id == planID }
    }

    private var phaseIndex: Int? {
        guard let pi = planIndex else { return nil }
        return planStore.plans[pi].phases.firstIndex { $0.id == phaseID }
    }

    private func durationMinutes(pi: Int, phi: Int) -> Binding<Int?> {
        Binding(
            get: {
                guard let d = planStore.plans[pi].phases[phi].duration else { return nil }
                return max(1, Int(d) / 60)
            },
            set: {
                planStore.plans[pi].phases[phi].duration = $0.map { TimeInterval($0 * 60) }
            }
        )
    }

    var body: some View {
        if let pi = planIndex, let phi = phaseIndex {
            VStack(spacing: 6) {
                Picker("Phase", selection: $planStore.plans[pi].phases[phi].name) {
                    ForEach(PlanNames.phases, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .pickerStyle(.navigationLink)

                HStack(spacing: 8) {
                    VStack(spacing: 0) {
                        Text("MIN")
                            .font(.system(size: 10))
                            .tracking(1)
                            .foregroundStyle(Color(white: 0.53))
                        Picker("MIN", selection: $planStore.plans[pi].phases[phi].minHR) {
                            ForEach(50...max(50, planStore.plans[pi].phases[phi].maxHR - 1), id: \.self) { v in
                                Text("\(v)").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 65)
                        .labelsHidden()
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 0) {
                        Text("MAX")
                            .font(.system(size: 10))
                            .tracking(1)
                            .foregroundStyle(Color(white: 0.53))
                        Picker("MAX", selection: $planStore.plans[pi].phases[phi].maxHR) {
                            ForEach(min(221, planStore.plans[pi].phases[phi].minHR + 1)...220, id: \.self) { v in
                                Text("\(v)").tag(v)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 65)
                        .labelsHidden()
                    }
                    .frame(maxWidth: .infinity)
                }

                Picker("Duration", selection: durationMinutes(pi: pi, phi: phi)) {
                    Text("∞").tag(nil as Int?)
                    ForEach(1...60, id: \.self) { min in
                        Text("\(min) min").tag(Optional(min))
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 55)

                Button {
                    planStore.plans[pi].phases.remove(at: phi)
                    planStore.save()
                    dismiss()
                } label: {
                    Text("Delete Phase")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
            .navigationTitle(planStore.plans[pi].phases[phi].name)
            .onDisappear { planStore.save() }
        }
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

#Preview("Plan – Timed") {
    NavigationStack {
        WorkoutView(manager: {
            let m = WorkoutManager()
            m.heartRate = 158
            m.zoneState = .inZone
            m.minHR = 145
            m.maxHR = 165
            m.phases = [
                Phase(name: "Warm-up", minHR: 110, maxHR: 130, duration: 300),
                Phase(name: "Tempo", minHR: 145, maxHR: 165, duration: 1200),
                Phase(name: "Cooldown", minHR: 110, maxHR: 130, duration: 300),
            ]
            m.currentPhaseIndex = 1
            m.phaseElapsedSeconds = 420
            return m
        }())
    }
}

#Preview("Plan – Open-Ended") {
    NavigationStack {
        WorkoutView(manager: {
            let m = WorkoutManager()
            m.heartRate = 118
            m.zoneState = .inZone
            m.minHR = 110
            m.maxHR = 130
            m.phases = [
                Phase(name: "Warm-up", minHR: 110, maxHR: 130),
                Phase(name: "Interval", minHR: 155, maxHR: 175, duration: 240),
                Phase(name: "Recovery", minHR: 120, maxHR: 140, duration: 120),
            ]
            m.currentPhaseIndex = 0
            m.phaseElapsedSeconds = 45
            return m
        }())
    }
}

#Preview("Plan List") {
    NavigationStack {
        PlanListView(planStore: PlanStore(), manager: WorkoutManager())
    }
}

#Preview("Plan Editor") {
    NavigationStack {
        PlanDetailView(planStore: {
            let s = PlanStore()
            if s.plans.isEmpty {
                s.plans = [Plan(name: "Tempo", phases: [
                    Phase(name: "Warm-up", minHR: 110, maxHR: 125, duration: 300),
                    Phase(name: "Tempo", minHR: 140, maxHR: 155, duration: 1200),
                    Phase(name: "Cooldown", minHR: 110, maxHR: 125, duration: 300),
                ])]
            }
            return s
        }(), planID: PlanStore().plans.first?.id ?? UUID(), manager: WorkoutManager())
    }
}

#Preview("Plan List – Empty") {
    NavigationStack {
        PlanListView(planStore: {
            let s = PlanStore()
            s.plans = []
            return s
        }(), manager: WorkoutManager())
    }
}

#Preview("Start Screen") {
    ContentView()
}
