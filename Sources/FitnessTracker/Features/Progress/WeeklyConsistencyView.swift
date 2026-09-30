import SwiftUI
import SwiftData

struct WeeklyActivity {
    let dayCount: Int
    let sessionCount: Int
    let days: Set<Date>
    let muscles: [String: Int]

    init(profile: Profile, start: Date, calendar: Calendar) {
        let end = calendar.date(byAdding: .day, value: 7, to: start)!
        let sessions = profile.sessions.filter { session in
            session.status == .completed && session.startedAt >= start && session.startedAt < end &&
                session.exerciseLogs.contains { $0.sets.contains { $0.completedAt != nil && !$0.isWarmUp && $0.reps > 0 } }
        }
        self.days = Set(sessions.map { calendar.startOfDay(for: $0.startedAt) })
        dayCount = days.count
        sessionCount = sessions.count
        var counts: [String: Int] = [:]
        for session in sessions {
            let groups = Set(session.exerciseLogs.filter { $0.sets.contains { $0.completedAt != nil && !$0.isWarmUp && $0.reps > 0 } }
                .flatMap { ($0.muscleGroup ?? $0.exercise?.muscleGroup ?? "Unspecified").split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) } })
            for group in groups { counts[group, default: 0] += 1 }
        }
        muscles = counts
    }
}

struct WeeklyConsistencyView: View {
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @State private var offset = 0
    private var calendar: Calendar { var value = Calendar.current; value.firstWeekday = 2; return value }
    private var start: Date {
        let current = calendar.dateInterval(of: .weekOfYear, for: .now)!.start
        return calendar.date(byAdding: .day, value: offset * 7, to: current)!
    }
    var body: some View {
        List {
            Section {
                HStack {
                    Button { offset -= 1 } label: { Image(systemName: "chevron.left").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Previous week")
                    Spacer()
                    Text(start, format: .dateTime.month().day()).font(.headline)
                    Spacer()
                    Button { offset += 1 } label: { Image(systemName: "chevron.right").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Next week").disabled(offset >= 0)
                }.buttonStyle(.borderless)
                Text("Monday–Sunday · Completed workouts, including imported baselines. Muscle counts show sessions that trained each group.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(profiles) { profile in
                let activity = WeeklyActivity(profile: profile, start: start, calendar: calendar)
                Section(profile.name) {
                    Text("\(activity.dayCount) training days · \(activity.sessionCount) workouts").font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))]) {
                        ForEach(0..<7, id: \.self) { index in
                            let day = calendar.date(byAdding: .day, value: index, to: start)!
                            VStack {
                                Text(day, format: .dateTime.weekday(.abbreviated)).font(.caption)
                                Image(systemName: activity.days.contains(day) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(activity.days.contains(day) ? Color.green : Color.secondary)
                            }.frame(minHeight: 48).accessibilityElement(children: .ignore)
                                .accessibilityLabel("\(day.formatted(date: .complete, time: .omitted)): \(activity.days.contains(day) ? "Trained" : "No completed workout")")
                        }
                    }
                    ForEach(activity.muscles.keys.sorted(), id: \.self) { muscle in
                        Text("\(muscle): \(activity.muscles[muscle]!) sessions")
                    }
                    if activity.sessionCount == 0 { Text("No completed workouts this week.").foregroundStyle(.secondary) }
                }
            }
        }.navigationTitle("Weekly consistency")
    }
}
