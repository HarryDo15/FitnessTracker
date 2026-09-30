import SwiftUI
import SwiftData

struct PunchCardHistoryView: View {
    @Query(sort: \PunchCard.startedAt, order: .reverse) private var cards: [PunchCard]

    var body: some View {
        List {
            let archived = cards.filter { $0.archivedAt != nil }.sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) }
            if archived.isEmpty { ContentUnavailableView("No claimed cards yet", systemImage: "gift") }
            ForEach(archived) { card in
                NavigationLink {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            PunchCardView(card: card)
                            if let date = card.archivedAt {
                                Text("Claimed \(date.formatted(date: .abbreviated, time: .omitted))").font(.headline)
                            }
                            ForEach(card.visits.sorted { $0.checkedInAt < $1.checkedInAt }) { visit in
                                Label(visit.dayKey?.split(separator: "|").last.map(String.init)
                                      ?? visit.checkedInAt.formatted(date: .abbreviated, time: .omitted), systemImage: "checkmark.circle")
                            }
                        }.padding()
                    }.navigationTitle(card.profile?.name ?? "Past card")
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.reward?.title ?? card.title).font(.headline)
                        Text("\(card.profile?.name ?? "Profile") · \(card.progress) gym visits").font(.subheadline)
                        if let date = card.archivedAt {
                            Text(date, style: .date).font(.caption).foregroundStyle(.secondary)
                        }
                    }.frame(minHeight: 56)
                }
            }
        }.navigationTitle("Past punch cards")
    }
}
