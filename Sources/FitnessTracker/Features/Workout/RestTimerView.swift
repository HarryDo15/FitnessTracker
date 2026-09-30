import SwiftUI

struct RestTimerView: View {
    let deadline: Date
    let extend: () -> Void
    let skip: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let remaining = WorkoutCalculations.remainingSeconds(until: deadline, now: timeline.date)
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
            layout {
                VStack(alignment: .leading) {
                    Text(remaining > 0 ? "Rest" : "Ready for your next set").font(.caption)
                    Text(WorkoutCalculations.clock(Double(remaining))).font(.title2.bold()).monospacedDigit()
                }.accessibilityElement(children: .ignore)
                    .accessibilityLabel(remaining > 0 ? "Rest remaining" : "Ready for your next set")
                    .accessibilityValue(SpokenWorkoutValue.time(remaining))
                HStack {
                Button(action: extend) { Text("+30s").frame(minWidth: 52, minHeight: 48) }
                    .buttonStyle(.bordered).accessibilityLabel("Add 30 seconds rest")
                Button(action: skip) { Text(remaining > 0 ? "Skip" : "Done").frame(minWidth: 48, minHeight: 48) }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(remaining > 0 ? "Skip rest timer" : "Dismiss finished rest timer")
                }
            }
        }
    }
}

#Preview { RestTimerView(deadline: .now.addingTimeInterval(75), extend: {}, skip: {}).padding() }
