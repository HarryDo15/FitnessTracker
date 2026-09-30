import SwiftUI
import SwiftData

struct GymVisitHistoryView: View {
    @Query(sort: \GymVisit.checkedInAt, order: .reverse) private var visits: [GymVisit]

    var body: some View {
        List {
            if visits.isEmpty { ContentUnavailableView("No gym visits yet", systemImage: "calendar") }
            ForEach(visits) { visit in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(visit.profile?.name ?? "Profile").font(.headline)
                        // The immutable date label stays stable after a device time-zone change.
                        Text(visit.dayKey?.split(separator: "|").last.map(String.init)
                             ?? visit.checkedInAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if visit.punchCard != nil {
                        Label("Punched", systemImage: "checkmark.seal.fill").font(.caption).foregroundStyle(.primary)
                    } else if visit.eligibleForPunch {
                        Text("Queued").font(.caption).foregroundStyle(.secondary)
                    }
                }.frame(minHeight: 48).accessibilityElement(children: .combine)
            }
        }.navigationTitle("Gym visits")
    }
}
