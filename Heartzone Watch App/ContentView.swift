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

                NavigationLink("Test Patterns") {
                    PatternTestView(manager: workoutManager)
                }
                .font(.caption)
            }
            .navigationTitle("HeartZone")
            .navigationDestination(isPresented: $showWorkout) {
                WorkoutView(manager: workoutManager,
                            minHR: Int(minHR),
                            maxHR: Int(maxHR))
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

struct WorkoutView: View {
    var manager: WorkoutManager
    let minHR: Int
    let maxHR: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Text(heartRateText)
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .foregroundStyle(heartRateColor)

            Text(zoneLabel)
                .font(.caption2)
                .foregroundStyle(heartRateColor)

            HStack(spacing: 4) {
                Text("\(minHR)")
                Text("–")
                Text("\(maxHR)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Button("Stop") {
                Task {
                    await manager.endWorkout()
                    dismiss()
                }
            }
            .tint(.red)
        }
        .navigationTitle("Workout")
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
        if hr < Double(minHR) { return .blue }
        if hr > Double(maxHR) { return .red }
        return .green
    }
}

struct PatternTestView: View {
    var manager: WorkoutManager
    private let device = WKInterfaceDevice.current()

    var body: some View {
        List {
            Section("Patterns") {
                Button("Unter Zone") { manager.playBelowZonePattern() }
                Button("Über Zone") { manager.playAboveZonePattern() }
                Button("Startup") { manager.playStartupPattern() }
            }
            Section("Einzelne Typen") {
                Button("notification") { device.play(.notification) }
                Button("click") { device.play(.click) }
            }
        }
        .navigationTitle("Test Patterns")
    }
}

#Preview {
    ContentView()
}
