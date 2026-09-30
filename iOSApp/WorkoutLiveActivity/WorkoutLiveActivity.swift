import ActivityKit
import WidgetKit
import SwiftUI
import WorkoutActivitySupport

@main
struct WorkoutLiveActivityBundle: WidgetBundle {
    var body: some Widget { WorkoutLiveActivityWidget() }
}

struct WorkoutLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                Label(context.attributes.profileName + " · Workout", systemImage: "dumbbell.fill").font(.headline)
                Text(context.state.exerciseName).font(.subheadline)
                HStack {
                    restTimer(context)
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Next set").font(.caption).foregroundStyle(.secondary)
                        Text(context.state.nextSet).font(.headline)
                    }
                }
            }.padding().activityBackgroundTint(Color.black.opacity(0.85)).activitySystemActionForegroundColor(.white)
                .foregroundStyle(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text(context.attributes.profileName).font(.headline) }
                DynamicIslandExpandedRegion(.trailing) { restTimer(context) }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack {
                        Text(context.state.exerciseName).font(.subheadline)
                        Text("Next: " + context.state.nextSet).font(.headline)
                    }
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
            } compactTrailing: {
                restTimer(context).frame(maxWidth: 64)
            } minimal: {
                Image(systemName: "dumbbell.fill")
            }
        }
    }

    @ViewBuilder private func restTimer(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        if let end = context.state.restEndsAt, end > context.state.restStartedAt, !context.isStale {
            Text(timerInterval: context.state.restStartedAt...end, countsDown: true)
                .monospacedDigit().font(.headline).accessibilityLabel("Rest time remaining")
        } else {
            Text("Ready").font(.headline)
        }
    }
}
